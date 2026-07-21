module Sensor
  module Query
    class DayLight < Helpers::Influx::Base
      def self.active?
        # Assume sun is shining if forecast is not available
        return true unless Config.exists?(:inverter_power_forecast)

        day_light = new(Date.current)

        # Same as above if sunrise or sunset is unavailable
        return true unless day_light.sunrise && day_light.sunset

        # Sun is shining when we are between sunrise and sunset
        day_light.sunrise.past? && day_light.sunset.future?
      end

      def initialize(date)
        super([:inverter_power_forecast], Timeframe.now)
        @date = date
      end

      def sunrise
        time_range&.first
      end

      def sunset
        time_range&.last
      end

      private

      def time_range
        @time_range ||=
          raw.map { |record| Time.zone.parse(record['_time']) }.sort!
      end

      def raw
        # The cached shape changed with Influx::CsvParser, hence the new key.
        Rails
          .cache
          .fetch("day_light_rows_#{@date}", expires_in: 24.hours) do
            query <<~QUERY
              data = #{from_bucket}
              |> #{range(start: @date.beginning_of_day, stop: @date.end_of_day)}
              |> #{filter}
              |> filter(fn: (r) => r["_value"] > 0)

              firstValue = data |> first()
              lastValue = data |> last()

              union(tables: [firstValue, lastValue])
            QUERY
          end
      end
    end
  end
end
