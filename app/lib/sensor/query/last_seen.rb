module Sensor
  module Query
    # When each sensor last delivered a data point, searched across the whole
    # history instead of a live window.
    #
    # Sensor::Query::Latest deliberately looks back only a day: it feeds the
    # dashboard, where anything older is not a reading anymore, and it records
    # the freshness it sees for the poll-interval estimator - both wrong for a
    # question about the past. That leaves it unable to tell "quiet for a
    # while" from "never delivered at all", which is exactly what this answers,
    # at the price of a scan back to the installation date. So ask it only
    # about the sensors in doubt; today its sole caller is the MCP tool
    # get_current_values, for the sensors missing from the live window.
    class LastSeen < Helpers::Influx::Base
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
          |> last()
        FLUX
      end
    end
  end
end
