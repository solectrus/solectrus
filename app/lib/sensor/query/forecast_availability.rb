module Sensor
  module Query
    # Check how many days of forecast data are available
    class ForecastAvailability < Helpers::Influx::Base
      def initialize(*sensor_names)
        super(sensor_names.flatten, nil)
      end

      def call(limit: 10.days)
        @limit = normalize_limit(limit)
        cache_key =
          "forecast_availability:#{sensor_names.sort.join(',')}:#{limit}"

        Rails.cache.fetch(cache_key, expires_in: 15.minutes) { max_date }
      end

      attr_reader :limit

      private

      def normalize_limit(limit)
        limit.is_a?(ActiveSupport::Duration) ? limit.in_days.to_i : limit
      end

      def max_date
        max_time = query_max_time
        return unless max_time

        date =
          complete_day?(max_time) ? max_time.to_date : max_time.to_date - 1.day
        [date, Date.current + limit.days].min
      end

      def complete_day?(time)
        time.seconds_since_midnight >= 16.hours
      end

      def query_max_time
        return if available_sensors.none?

        result = query(flux_query)
        extract_time(result)
      end

      def flux_query
        start_time = Time.current.utc.iso8601
        [
          from_bucket,
          "|> range(start: #{start_time}, stop: #{limit}d)",
          "|> #{filter}",
          '|> keep(columns: ["_time"])',
          '|> group(columns: [])',
          '|> max(column: "_time")',
        ].join("\n")
      end

      def extract_time(flux_result)
        return if flux_result.blank?

        flux_result.each do |table|
          table.records.each do |record|
            time_value = record.values['_time']
            return Time.zone.parse(time_value) if time_value
          end
        end

        nil
      end
    end
  end
end
