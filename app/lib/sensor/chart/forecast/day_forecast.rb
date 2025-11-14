module Sensor
  module Chart
    class Forecast < Base
      # Represents forecast data for a single day
      class DayForecast
        MIN_ENTRIES = 2
        MIN_TIME_SPAN_HOURS = 8
        LOW_POWER_THRESHOLD = 10 # Watts - threshold for "day complete"

        private_constant :MIN_ENTRIES,
                         :MIN_TIME_SPAN_HOURS,
                         :LOW_POWER_THRESHOLD

        attr_reader :date, :entries

        def initialize(date, entries)
          @date = date
          @entries = entries.sort_by(&:first) # Ensure chronological order
        end

        def valid?
          sufficient_entries? && sufficient_time_span?
        end

        def noon_timestamp_ms
          timestamps = entries.map(&:first)
          noon_time = timestamps.min_by { |t| (t.hour - 12).abs }
          noon_time.to_i * 1000
        end

        def total_kwh
          return unless should_calculate_total?

          entries_for_calculation =
            if date.today?
              # For today, only include future entries (remaining energy)
              entries.select { |timestamp, _| timestamp > Time.current }
            else
              entries
            end

          EnergyCalculator.calculate_kwh(entries_for_calculation)
        end

        private

        def sufficient_entries?
          entries.size >= MIN_ENTRIES
        end

        def sufficient_time_span?
          return false if entries.empty?

          timestamps = entries.map(&:first)
          time_span_hours = (timestamps.max - timestamps.min) / 3600.0
          time_span_hours >= MIN_TIME_SPAN_HOURS
        end

        def should_calculate_total?
          day_complete? || date.today?
        end

        def day_complete?
          return false unless sufficient_time_span?

          first_power_value = entries.first.last
          return false unless first_power_value

          first_power_value.abs <= LOW_POWER_THRESHOLD
        end
      end
    end
  end
end
