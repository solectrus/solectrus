module Sensor
  module Query
    # The highest value of a sensor in a period, for example the state of
    # charge of a car before it drove away (see Car::Live).
    class Highest < Helpers::Influx::Base
      # `from` and `to` are times. The period includes both.
      def initialize(sensor_name, from:, to:)
        super([sensor_name], Timeframe.now)
        @from = from
        @to = to
      end

      # The highest value, or nil without a reading in the period
      def call
        return if available_sensors.empty?

        query(build_flux_query).filter_map { it['_value'] }.max
      end

      private

      def build_flux_query
        <<~FLUX
          #{from_bucket}
          |> #{range(start: @from, stop: @to + 1.second)}
          |> #{filter}
          |> max()
        FLUX
      end

      # A period ends at the latest reading, so each new reading asks with a
      # new key. A period that ended would stay cached forever (see #range),
      # and these keys would pile up.
      def cache_options(**) = { expires_in: 1.hour }
    end
  end
end
