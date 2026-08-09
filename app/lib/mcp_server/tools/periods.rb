module McpServer
  module Tools
    # One value per calendar period over a timeframe, in date order: the series
    # behind every "per month this year" chart.
    #
    # get_totals, grouped - and it is that literally, not by analogy. The very
    # query get_totals runs takes a `group_by`, and the SOLECTRUS web UI plots
    # its bar charts from it (Sensor::Chart::Base#build_sql_series). So this
    # tool answers the same sensors get_totals answers, from the same store it
    # would have picked, and adds nothing but the serialization.
    #
    # Which store that is stays Sensor::Query::Total's decision, as it is for
    # get_totals. This tool never names one. The earlier attempt built the same
    # answer out of Sensor::Query::Ranking, which meant re-deciding the store,
    # re-implementing the gap padding, and bending a RANKING into a time axis.
    class Periods < Base
      tool_name 'get_periods'
      title 'Get a value per day/week/month/year'

      # Entries across the WHOLE response, shared by the requested sensors -
      # the budget get_ranking spends, for the same payload at the same end.
      MAX_ENTRIES = 400
      public_constant :MAX_ENTRIES

      # Finest first: the over-budget message walks it to name the first width
      # that would fit.
      PERIODS = %w[day week month year].freeze
      private_constant :PERIODS

      description <<~TEXT.strip
        A value per period over a timeframe, in DATE order: "generation per
        month in 2025", "consumption per day last week", "autarky per year
        since installation". This is get_totals grouped, so it answers the same
        sensors, with the same units after aggregation, and is exact per period
        rather than a mean over samples.

        The list is DENSE: every period the timeframe covers appears, in order,
        a period without data as a null. So values[i] is at `start` + i
        periods, and `indices` is never sent.

        For the periods ordered by size ask get_ranking, for one number over
        the whole timeframe get_totals, for a curve below a day get_series. A
        timeframe of hours has no periods to group and is rejected.

        An entry is labelled with its period START but aggregated over the days
        inside the timeframe alone, so a period the timeframe cuts into is a
        fragment — `partial_at` names those, the one still running included.

        Capped at #{MAX_ENTRIES} entries SHARED by the requested sensors. Over
        that the call is REFUSED rather than shortened, because a cut series
        plots as a whole one — ask for a coarser `period`, fewer sensors or a
        shorter timeframe.
      TEXT
      input_schema(
        properties: {
          sensors:
            sensors_property(
              "Sensor names (from list_sensors), at most #{MAX_SENSORS}.",
              max: MAX_SENSORS,
            ),
          timeframe: timeframe_property('The range the series covers.'),
          period: {
            type: 'string',
            enum: PERIODS,
            default: 'day',
            description: 'Width of each entry.',
          },
        },
        required: %w[timeframe sensors],
      )
      read_only idempotent: true

      def self.perform(timeframe:, sensors:, period: 'day', **)
        resolved, unknown = resolve_sensors(sensors, max: MAX_SENSORS)
        enforce_supported!(resolved, :periods, unknown)

        tf = parse_timeframe(timeframe)
        enforce_groupable!(tf)
        enforce_budget!(tf, period.to_sym, resolved.size)

        aggregations = resolved.index_with { meta_aggregation(it) }

        # After the validations, so a refused call spends no time building
        # summaries it will not read.
        pending = McpServer::Summaries.refresh(tf)
        data = grouped(tf, period.to_sym, aggregations)

        {
          **timeframe_preamble(tf, unknown),
          **pending,
          period:,
          results:
            aggregations.map { |sensor, agg| entry(sensor, agg, data, tf, period.to_sym) },
        }
      end

      # An hour window has no calendar periods inside it, and asking anyway
      # reaches the InfluxDB half of Sensor::Query::Total, whose DSL carries no
      # `group_by` at all - a NoMethodError where the client deserves a
      # sentence. Rejected by the same rule that decides the store, so the two
      # cannot disagree.
      def self.enforce_groupable!(timeframe)
        return unless timeframe.now? || timeframe.hours?

        raise ArgumentError,
              "A timeframe of hours (\"#{timeframe}\") holds no whole days, " \
                'weeks, months or years to group by, so get_periods has ' \
                'nothing to return per period. Use get_series for a curve ' \
                'inside an hour window, or name a day or longer here.'
      end
      private_class_method :enforce_groupable!

      # A series longer than the budget is refused rather than cut, following
      # get_series rather than get_ranking: a top-10 shortened to five is still
      # a top-5, but a curve cut to its first 400 points plots as a whole one.
      # The count follows from the timeframe and the period alone, so refusing
      # costs no query.
      def self.enforce_budget!(timeframe, period, sensor_count)
        periods = PeriodAxis.period_count(timeframe, period)
        return if periods * sensor_count <= MAX_ENTRIES

        raise ArgumentError,
              "This asks for #{periods * sensor_count} entries (#{periods} " \
                "periods x #{sensor_count} sensor(s)), above the " \
                "#{MAX_ENTRIES} get_periods may spend. A shortened series " \
                'would plot as a whole one, so it is refused instead. ' \
                "#{coarser_hint(timeframe, period, sensor_count)}"
      end
      private_class_method :enforce_budget!

      # The finest period that WOULD fit, named rather than left to the client
      # to search for: "use a coarser period" sends it guessing, and every
      # guess that is still too fine costs another round trip.
      def self.coarser_hint(timeframe, period, sensor_count)
        fitting =
          PERIODS
            .drop(PERIODS.index(period.to_s) + 1)
            .find { PeriodAxis.period_count(timeframe, it.to_sym) * sensor_count <= MAX_ENTRIES }
        return 'Ask for fewer sensors or a shorter timeframe.' unless fitting

        "Ask for period \"#{fitting}\" " \
          "(#{PeriodAxis.period_count(timeframe, fitting.to_sym)} periods), " \
          'for fewer sensors, or for a shorter timeframe.'
      end
      private_class_method :coarser_hint

      # How the DAYS of a period combine into it. Energy, money and CO2
      # accumulate, so a month is the sum of its days; a percentage or a
      # temperature averages - summing autarky would report 2400 %.
      #
      # The same choice Sensor::Chart::Base makes for its bar charts, and made
      # here rather than taken from the client: which of the two a unit wants
      # is a fact about the sensor, not a preference. `default_aggregation` is
      # the fallback and is allowed by definition, so the walk always lands.
      AVERAGED_UNITS = %i[celsius percent].freeze
      private_constant :AVERAGED_UNITS

      def self.meta_aggregation(sensor)
        preferred = AVERAGED_UNITS.include?(sensor.unit) ? :avg : :sum

        sensor.allowed_aggregations.include?(preferred) ? preferred : sensor.default_aggregation
      end
      private_class_method :meta_aggregation

      # One grouped query for every requested sensor, which is what get_totals
      # does too - and what keeps this tool from issuing one query per sensor
      # the way a ranking has to.
      def self.grouped(timeframe, period, aggregations)
        Sensor::Query::Total.new(timeframe) do |q|
          aggregations.each do |sensor, meta|
            q.public_send(meta, sensor.name, sensor.default_aggregation)
          end

          q.group_by period
        end.call
      end
      private_class_method :grouped

      def self.entry(sensor, aggregation, data, timeframe, period)
        unit = mcp_unit(sensor, aggregation)
        rows =
          PeriodAxis.mark_partial(
            dense(sensor, aggregation, data, timeframe, period),
            timeframe,
            period,
          )

        {
          sensor: sensor.name,
          display_name: mcp_display_name(sensor),
          unit:,
          aggregation:,
          **PeriodAxis.axis(
            rows.map { it.merge(value: Precision.round(it[:value], unit)) },
            period,
          ),
        }
      end
      private_class_method :entry

      # Every period of the timeframe, a null where nothing was measured.
      #
      # The grouped query already pads the periods it knows are missing, but
      # only for day, month and year - a weekly grouping comes back with holes.
      # Padding here instead of relying on that makes the promise the
      # description gives ("the list is DENSE") a property of this tool rather
      # than of a detail two layers down.
      #
      # Across the timeframe's EFFECTIVE bounds, which already stop at the
      # installation date and at today, so no padded period could ever have
      # held data.
      def self.dense(sensor, aggregation, data, timeframe, period)
        values = values_for(sensor, aggregation, data)

        PeriodAxis
          .period_range(
            PeriodAxis.period_start(timeframe.effective_beginning_date, period),
            PeriodAxis.period_start(timeframe.effective_ending_date, period),
            period,
          )
          .map { |date| { date:, value: values[date] } }
      end
      private_class_method :dense

      # The {period => value} hash for one sensor, read through the ACCESSOR
      # rather than out of `raw_data`.
      #
      # The two are the same thing only for a stored sensor. A derived one -
      # autarky, savings, house_power_without_custom - never reaches raw_data
      # under its own name: what lands there are its DEPENDENCIES, and the
      # sensor itself gets a singleton accessor from
      # Query::Base#process_calculated_sensors. Reading raw_data therefore
      # answered null for every ratio and every cost while get_totals answered
      # a number for the same month. Series::Points reads the same way, for the
      # same reason.
      def self.values_for(sensor, aggregation, data)
        return {} unless data.respond_to?(sensor.name)

        data.public_send(sensor.name, aggregation, sensor.default_aggregation) || {}
      end
      private_class_method :values_for
    end
  end
end
