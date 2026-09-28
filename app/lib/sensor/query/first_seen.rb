module Sensor
  module Query
    # When each sensor delivered its first data point, the counterpart of
    # Sensor::Query::LastSeen.
    #
    # Sensor::SummaryInvalidator asks it about added sensors: one with data
    # before today is missing in the existing summaries.
    #
    # first() instead of limit(n: 1): InfluxDB pushes first() down to the
    # storage engine, which reads one point per series. limit() reads every
    # point of the range before. Against a remote InfluxDB with six years of
    # data, this was ~40 ms versus 1-2 s per field.
    class FirstSeen < Helpers::Influx::Base
      def initialize(sensor_names)
        super(sensor_names, Timeframe.new('all'))
      end

      # { sensor_name => Time }, omitting sensors that never delivered.
      def call
        return {} if available_sensors.empty?

        parse_flux_result(query(build_flux_query))[:times]
      end

      private

      def build_flux_query
        <<~FLUX
          #{from_bucket}
          |> #{range(start: @timeframe.beginning, stop: @timeframe.ending)}
          |> #{filter}
          |> first()
        FLUX
      end
    end
  end
end
