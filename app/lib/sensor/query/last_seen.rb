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
    # about the sensors in doubt: get_current_values asks for the sensors
    # missing from the live window, get_system_info only when that window is
    # empty for every sensor at once.
    class LastSeen < Helpers::Influx::Base
      # `before` ends the search at a time, for example at the start of a
      # chart. A search that ends in the past stays cached.
      def initialize(sensor_names, before: nil)
        super(sensor_names, Timeframe.new('all'))
        @before = before
      end

      # { sensor_name => Time }, omitting sensors that never delivered.
      def call
        readings[:times]
      end

      # The last value of each sensor with its time, like
      # Sensor::Query::Latest: { sensor_name => value, times: { ... } }
      def readings
        return { times: {} } if available_sensors.empty?

        @readings ||= parse_flux_result(query(build_flux_query))
      end

      private

      def build_flux_query
        <<~FLUX
          #{from_bucket}
          |> #{range(start: @timeframe.beginning, stop: @before || @timeframe.ending)}
          |> #{filter}
          |> last()
        FLUX
      end
    end
  end
end
