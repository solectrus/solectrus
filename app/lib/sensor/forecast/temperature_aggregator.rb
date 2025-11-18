module Sensor
  module Forecast
    # Calculates temperature aggregation for a day
    class TemperatureAggregator
      def initialize(
        date,
        forecast_entries,
        actual_temp_data,
        forecast_temp_data
      )
        @date = date
        @forecast_entries = forecast_entries
        @actual_temp_data = actual_temp_data
        @forecast_temp_data = forecast_temp_data
      end

      attr_reader :date,
                  :forecast_entries,
                  :actual_temp_data,
                  :forecast_temp_data

      def call
        {
          noon_timestamp: calculate_noon_timestamp_ms,
          avg_temp: calculate_average_temp,
        }
      end

      private

      def calculate_noon_timestamp_ms
        noon = date.to_time + Sensor::Chart::Concerns::Forecast::NOON_HOUR.hours
        noon.to_i * Sensor::Chart::Concerns::Forecast::MS_PER_SECOND
      end

      def calculate_average_temp
        temps =
          if date == Date.current && actual_temp_data
            combine_today_temperatures
          else
            forecast_entries.filter_map(&:last)
          end

        return if temps.empty?

        temps.sum / temps.size.to_f
      end

      def combine_today_temperatures
        now = Time.current

        # Single pass through data using partition
        actual_temps = extract_temps(actual_temp_data) { |ts| ts <= now }
        forecast_temps = extract_temps(forecast_temp_data) { |ts| ts > now }

        actual_temps + forecast_temps
      end

      def extract_temps(data)
        return [] unless data

        data.filter_map do |timestamp, value|
          value if timestamp.to_date == date && yield(timestamp)
        end
      end
    end
  end
end
