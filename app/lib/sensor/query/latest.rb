module Sensor
  module Query
    # Fetches the latest/current values for sensors directly from InfluxDB
    # Used for: Dashboard live data, current sensor readings
    class Latest < Helpers::Influx::Base
      def initialize(sensor_names)
        super(sensor_names, Timeframe.now)
      end

      protected

      def create_data_instance(raw_data, timeframe)
        Sensor::Data::Single.new(
          raw_data[:payload],
          timeframe:,
          time: raw_data[:time],
        )
      end

      private

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
