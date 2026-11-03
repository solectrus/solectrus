module McpServer
  module Tools
    # The figures of the car page for a timeframe: the distance, the charging
    # and the driving of all cars or of one car. A thin layer over Car::Report,
    # which owns every rule: what "all" counts, why the driving cost differs
    # from the charging cost, when a value is missing.
    #
    # The report reads the days of whole years around the timeframe (see
    # Car::Report.reach), so the build it needs can be far more than the month
    # McpServer::Summaries builds in one call. Up to that month it builds them
    # like the other tools. Beyond it the call stops instead of answering with
    # a note: a missing day changes the rates of the days around it, so the
    # error is in each figure and no sum is short by a known amount.
    class CarCosts < Base
      tool_name 'get_car_costs'
      title 'Get electric car costs'
      description <<~TEXT.strip
        Electric cars over whole days: distance, charging (energy and cost by
        source: pv/grid of the wallbox, or `wallbox` without a power splitter,
        and offsite) and driving (energy and cost of the distance, per 100 km).

        Without `car`: all cars, listed by number, plus guest charging
        (repeated as guest_charging). unassigned_charging counts for no car.

        Driving cost is not charging cost: the battery carries energy across
        days, so answer "cost per km/of driving" from driving, "cost of
        charging" from charging.

        Energy in Wh, money in system currency. null = no data (no odometer, no
        price; uncosted_sessions counts sessions without one).

        comparison, only with fuel prices: a combustion car for the same
        distance. savings = combustion.total - car.total. car.total adds the
        payments to the energy, by category and an income negative, so the
        cost of driving stays `driving`. running_costs are the shared payments
        (insurance, maintenance) that the combustion car has too. The purchase
        stays out, so give differences, never a percentage or a factor. Name
        each of `gaps`. comparison_note says why a comparison is missing.
      TEXT
      input_schema(
        properties: {
          timeframe: timeframe_property('The period, whole days only (not "now", not "P24H").'),
          car: {
            type: 'integer',
            minimum: 1,
            maximum: Sensor::Cars::MAX,
            description: 'The number of one car. Omit for all cars.',
          },
        },
        required: %w[timeframe],
      )
      read_only idempotent: true

      # The tool exists only with a car, because each tool costs every session
      # its description
      def self.available? = Car.configured.any?

      def self.perform(timeframe:, car: nil, **)
        tf = parse_timeframe(timeframe)
        raise ArgumentError, whole_days_message(timeframe) if tf.now? || tf.hours?

        selected = find_car(car)
        summarize(tf)

        cars = selected ? [selected] : CarSelection.new(nil, timeframe: tf).offered
        report = Car::Report.new(tf, cars, guest: selected.nil?)

        {
          **preamble(tf),
          currency: Rails.configuration.x.currency,
          cars: cars.map { { number: it.id, name: it.display_name } },
          **figures(report),
          **(selected ? {} : others(report)),
          **Comparison.for(report),
        }
      end

      # Two notes of the other tools do not fit here. The one of a running
      # period speaks of the aggregation of each entry, which this tool has
      # none of: here the sums are cut short, and the rates are not. The one of
      # the future points to get_forecast, which knows no car.
      RUNNING_NOTE =
        'This period has not ended yet, so the sums cover it only up to now ' \
          'and are smaller for that, not for driving or charging less. The ' \
          'rates per 100 km and km_per_day are not cut short.'.freeze
      FUTURE_NOTE =
        'This timeframe lies entirely in the future, so the cars have not ' \
          'driven or charged in it yet.'.freeze
      private_constant :RUNNING_NOTE, :FUTURE_NOTE

      def self.preamble(timeframe)
        preamble = timeframe_preamble(timeframe, [])
        if timeframe.beginning.to_date > Date.current
          preamble[:timeframe_note] = FUTURE_NOTE
        elsif timeframe.ending > Time.current
          preamble[:timeframe_note] ||= RUNNING_NOTE
        end
        preamble
      end
      private_class_method :preamble

      def self.summarize(timeframe)
        pending = Car::Report.pending_report_days(timeframe)
        raise ArgumentError, pending_days_message(pending) if pending.size > McpServer::Summaries::MAX_DAYS

        Sensor::Summarizer.new(pending).call
      end
      private_class_method :summarize

      def self.find_car(number)
        return if number.nil?

        Car.configured.find { it.id == number.to_i } ||
          raise(ArgumentError, "Unknown car #{number}. This instance has: #{car_list}.")
      end
      private_class_method :find_car

      def self.car_list = Car.configured.map { "#{it.id} (#{it.display_name})" }.join(', ')
      private_class_method :car_list

      def self.figures(report)
        {
          distance_km: Precision.round(report.distance, :kilometer),
          km_per_day: Precision.round(report.km_per_day, :kilometer),
          charging: charging(report),
          driving: driving(report),
        }
      end
      private_class_method :figures

      def self.charging(report)
        sessions = report.sessions
        {
          **energy_and_cost(sessions),
          **(sessions.costed? ? {} : { uncosted_sessions: sessions.uncosted }),
          sources:
            report.sources.to_h do |source|
              [source.key, { energy_wh: wh(source.kwh), cost: cost(sessions, source.cost) }]
            end,
        }
      end
      private_class_method :charging

      def self.driving(report)
        totals = report.driving
        {
          energy_wh: Precision.round(report.driving_energy, :watt_hour),
          cost: money(report.driving_cost),
          kwh_per_100km: Precision.round(totals.consumption_per_100km, :kwh_per_100km),
          cost_per_100km: Precision.round(totals.cost_per_100km, :money_per_100km),
        }
      end
      private_class_method :driving

      # The charging of all cars leaves out the sessions of no car and names
      # the guests in it, as the page does
      def self.others(report)
        {
          **sessions_entry(:guest_charging, report.guest_sessions),
          **sessions_entry(:unassigned_charging, report.unassigned_sessions),
        }
      end
      private_class_method :others

      def self.sessions_entry(key, sessions)
        sessions.any? ? { key => energy_and_cost(sessions) } : {}
      end
      private_class_method :sessions_entry

      def self.energy_and_cost(sessions)
        { energy_wh: wh(sessions.kwh), cost: cost(sessions, sessions.cost) }
      end
      private_class_method :energy_and_cost

      # null where no session has a price. Without a session nothing was
      # charged, which costs 0 and is no missing price.
      def self.cost(sessions, value)
        money(value) if sessions.none? || sessions.cost?
      end
      private_class_method :cost

      def self.wh(kwh) = Precision.round(kwh * 1000, :watt_hour)
      private_class_method :wh

      def self.money(value) = Precision.round(value, :money)
      private_class_method :money

      def self.whole_days_message(timeframe)
        "Invalid timeframe \"#{timeframe}\": the car figures are kept per day. " \
          'Ask for a day ("2026-06-21") or longer.'
      end
      private_class_method :whole_days_message

      def self.pending_days_message(pending)
        "#{pending.size} days from #{pending.min.iso8601} to #{pending.max.iso8601} " \
          'have no summary yet. The car figures read them, so this call stops ' \
          "instead of answering wrong. It builds at most #{McpServer::Summaries::MAX_DAYS} " \
          'days: opening the car page of the same timeframe in the SOLECTRUS ' \
          'web UI builds them. Tell the user so, and do not retry before.'
      end
      private_class_method :pending_days_message
    end
  end
end
