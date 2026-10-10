module Sensor
  module Query
    # Whether a sensor changed its value since a time, for example whether
    # the plug of the wallbox changed since a reading of a car (see
    # Car::Live).
    #
    # The query takes the last value of each 5 minutes, like
    # Helpers::Influx::DailyCurves, which InfluxDB reads from its storage
    # directly and which works with each type. A change that returns within
    # the same 5 minutes is lost.
    class ChangedSince < Helpers::Influx::Base
      def initialize(sensor_name, since:)
        super([sensor_name], Timeframe.now)
        @since = since
      end

      def call
        return false if available_sensors.empty?

        query(build_flux_query).map { value(it['_value']) }.uniq.size > 1
      end

      private

      # A boolean can come as a number or as text (see
      # Sensor::Units::Boolean), so 1 and "true" are the same value
      def value(raw_value)
        boolean? ? Sensor::Units::Boolean.parse(raw_value) : raw_value
      end

      def boolean? = Sensor::Registry[sensor_names.first].unit == :boolean

      def build_flux_query
        <<~FLUX
          #{from_bucket}
          |> #{range(start: @since)}
          |> #{filter}
          |> aggregateWindow(every: 5m, fn: last, createEmpty: false)
        FLUX
      end
    end
  end
end
