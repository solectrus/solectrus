module McpServer
  module Tools
    # Returns the forecast for the coming days: PV generation as energy sums
    # (today's remaining + per upcoming day) and, when configured, the outdoor
    # temperature as daily min/max/avg. This is the forecast counterpart to
    # get_totals (which only knows measured actuals).
    #
    # The energy integration / day aggregation live in the shared domain classes
    # Sensor::Forecast::Day / TodayAnalyzer (also used by the /forecast UI); this
    # tool only fetches the series and formats the result.
    class Forecast < Base
      GENERATION_SENSOR = :inverter_power_forecast
      TEMPERATURE_SENSOR = :outdoor_temp_forecast
      FETCH_INTERVAL = 15.minutes
      # Upper bound for the Influx scan; the real horizon emerges from the data.
      MAX_HORIZON = 10.days

      # An absent forecast is not a forecast of zero, and nothing in the
      # numbers distinguishes the two: `today_remaining` is a plain Wh figure,
      # so an empty scan reported as 0 becomes a claim about the weather made
      # from no data at all. Same reasoning as Facts::TIMEFRAME_NOTE, for the
      # one gap no timeframe can explain - the provider is not configured yet,
      # has not been fetched yet, or is failing.
      NO_DATA_NOTE =
        'No forecast data is stored, so this is NOT a forecast of zero: the ' \
          'forecast provider has delivered nothing (not set up yet, not ' \
          'fetched yet, or failing). Report it as "no forecast available", ' \
          'never as "no generation expected".'.freeze

      private_constant :GENERATION_SENSOR,
                       :TEMPERATURE_SENSOR,
                       :FETCH_INTERVAL,
                       :MAX_HORIZON,
                       :NO_DATA_NOTE

      tool_name 'get_forecast'
      title 'Get the PV generation and temperature forecast'
      description <<~TEXT.strip
        The forecast for the coming days, as far as it reaches — "what's still
        coming today?", "how much will tomorrow bring?", "how warm will it get?"

        - `generation`: expected PV generation in Wh (÷1000 for kWh).
          `today_remaining` counts only the part AFTER now, so energy already
          generated today is not included; `days` gives the full expected energy
          per upcoming day.
        - `temperature`: daily min/max/avg in °C for today and the upcoming
          days. Present only when an outdoor temperature forecast is configured.

        Where no forecast has been stored at all, `today_remaining` is null and
        a `forecast_note` says so. That is "no forecast available", never "no
        generation expected".

        For measured, historical values use get_totals.
      TEXT
      input_schema(properties: {})
      read_only idempotent: false

      def self.perform(**)
        unless Sensor::Config.exists?(GENERATION_SENSOR)
          raise ArgumentError, "Forecast sensor '#{GENERATION_SENSOR}' is not configured."
        end

        now = Time.current
        series = fetch_series(now)
        entries = entries_for(series, GENERATION_SENSOR)

        result = {
          timezone: Time.zone.name,
          generated_at: now.iso8601,
          **(entries.empty? ? { forecast_note: NO_DATA_NOTE } : {}),
          generation: generation_section(entries, now),
        }
        temperature = temperature_section(series, now)
        result[:temperature] = temperature if temperature

        result
      end

      # --- Generation (energy, Wh) -----------------------------------------

      # `today_remaining` is null rather than 0 where nothing was delivered:
      # 0 is a forecast, null is the absence of one, and only the second is
      # true. `days` needs no such guard - an empty list cannot be misread as
      # a prediction. NO_DATA_NOTE spells the distinction out.
      def self.generation_section(entries, now)
        {
          unit: 'Wh',
          today_remaining: entries.any? ? energy(today_remaining_wh(entries, now)) : nil,
          days:
            upcoming_days(entries, now).map do |date, wh|
              { date: date.iso8601, expected: energy(wh) }
            end,
        }
      end
      private_class_method :generation_section

      # Forecast energy (Wh) still expected from now until the end of today -
      # only the buckets after now, so the current day is not double-counted.
      def self.today_remaining_wh(entries, now)
        Sensor::Forecast::TodayAnalyzer.new(entries, current_time: now).remaining_wh
      end
      private_class_method :today_remaining_wh

      # [[date, expected_wh], ...] for each upcoming day (after today) that
      # carries enough forecast data, in chronological order.
      def self.upcoming_days(entries, now)
        days_from(entries, now.to_date + 1).filter_map do |date, day_entries|
          wh = Sensor::Forecast::Day.new(date, day_entries).total_wh
          [date, wh] if wh
        end
      end
      private_class_method :upcoming_days

      # --- Temperature (daily min/max/avg, Celsius) -------------------------

      def self.temperature_section(series, now)
        return unless Sensor::Config.exists?(TEMPERATURE_SENSOR)

        days =
          days_from(entries_for(series, TEMPERATURE_SENSOR), now.to_date)
            .filter_map { |date, day_entries| temperature_day(date, day_entries) }

        { unit: '°C', days: }
      end
      private_class_method :temperature_section

      # Day#valid? (>= 2 samples over >= 8 h) drops boundary-bucket artifacts
      # and the partial day at the edge of the forecast horizon.
      #
      # The generation side gates on Day#total_wh, which shares the 8-hour span
      # but additionally wants the day to open near zero - a curve that starts
      # at full power is a day the horizon cut into. So the two sections can
      # end on different dates, and neither list's length follows from the
      # other's.
      def self.temperature_day(date, entries)
        return unless Sensor::Forecast::Day.new(date, entries).valid?

        values = entries.filter_map(&:last)
        return if values.empty?

        {
          date: date.iso8601,
          min: temperature(values.min),
          max: temperature(values.max),
          avg: temperature(values.sum / values.size),
        }
      end
      private_class_method :temperature_day

      # [[date, day_entries], ...] grouped by day from `since` onward, in
      # chronological order.
      def self.days_from(entries, since)
        entries
          .group_by { |timestamp, _| timestamp.to_date }
          .select { |date, _| date >= since }
          .sort_by(&:first)
      end
      private_class_method :days_from

      # --- Shared fetch -----------------------------------------------------

      # Single Influx scan over the forecast horizon for all configured forecast
      # sensors at once; the real horizon emerges from the data.
      def self.fetch_series(now)
        today = now.to_date
        Sensor::Query::Series.new(
          [GENERATION_SENSOR, TEMPERATURE_SENSOR].select do |name|
            Sensor::Config.exists?(name)
          end,
          Timeframe.new("#{today}..#{today + MAX_HORIZON}"),
          timestamp_method: :to_time,
          interval: FETCH_INTERVAL,
        ).call(interpolate: true)
      end
      private_class_method :fetch_series

      # {time => value} forecast samples for one sensor, null padding buckets
      # dropped (genuine "no data" is an absent day).
      def self.entries_for(series, sensor_name)
        (series&.raw_for(sensor_name) || {}).compact
      end
      private_class_method :entries_for

      def self.energy(value)
        Precision.round(value, :watt_hour)
      end
      private_class_method :energy

      def self.temperature(value)
        Precision.round(value, :celsius)
      end
      private_class_method :temperature
    end
  end
end
