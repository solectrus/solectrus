module Sensor
  module Query
    # Fetches the latest/current values for sensors directly from InfluxDB
    # Used for: Dashboard live data, current sensor readings
    class Latest < Helpers::Influx::Base
      def initialize(sensor_names)
        super(sensor_names, Timeframe.now)
      end

      protected

      def fetch_raw_data
        super.tap do |raw_data|
          # Feed the freshness of the just-fetched value into the adaptive
          # poll-interval estimator. `:time` is the timestamp of the newest
          # data point, so its age tells us how often InfluxDB is updated.
          Influx::PollInterval.record(raw_data[:time])

          drop_stale_values!(raw_data)
        end
      end

      def create_data_instance(raw_data, timeframe)
        Sensor::Data::Single.new(
          raw_data[:payload],
          timeframe:,
          time: raw_data[:time],
        )
      end

      private

      # Drop sensor values whose timestamp is older than the sensor's max_age.
      # The Flux `last()` returns the most recent point within the 1-day range
      # regardless of how old it is, so without this filter the dashboard
      # would keep showing the last seen value indefinitely after a data
      # source goes offline.
      def drop_stale_values!(raw_data)
        times = raw_data[:times] || {}
        now = Time.current

        raw_data[:payload].delete_if do |sensor_name, _value|
          time = times[sensor_name]
          next false unless time

          (now - time) > Sensor::Registry[sensor_name].max_age
        end
      end

      def build_flux_query
        <<~FLUX
          #{from_bucket}
          |> #{range(start: 1.day.ago)}
          |> #{filter}
          |> last()
        FLUX
      end
    end
  end
end
