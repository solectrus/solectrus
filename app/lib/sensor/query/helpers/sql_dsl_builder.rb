module Sensor
  module Query
    module Helpers
      # DSL Builder for Sensor::Query::Sql to create fluent API for sensor requests
      #
      # Usage:
      #   builder = SqlDslBuilder.new
      #   builder.sum :house_power, :sum
      #   builder.timeframe 2025
      #   builder.group_by :month
      class SqlDslBuilder
        def initialize
          @sensor_requests = []
          @timeframe_value = nil
          @group_by_value = nil
        end

        attr_reader :sensor_requests, :timeframe_value, :group_by_value

        # DSL methods for aggregations
        def sum(sensor_name, base_aggregation = :sum)
          validate_aggregation(sensor_name, :sum)
          @sensor_requests << [sensor_name, :sum, base_aggregation]
        end

        def avg(sensor_name, base_aggregation = :avg)
          validate_aggregation(sensor_name, :avg)
          @sensor_requests << [sensor_name, :avg, base_aggregation]
        end

        def min(sensor_name, base_aggregation = :min)
          validate_aggregation(sensor_name, :min)
          @sensor_requests << [sensor_name, :min, base_aggregation]
        end

        def max(sensor_name, base_aggregation = :max)
          validate_aggregation(sensor_name, :max)
          @sensor_requests << [sensor_name, :max, base_aggregation]
        end

        # DSL methods for configuration
        def timeframe(value)
          @timeframe_value =
            value.is_a?(Timeframe) ? value : Timeframe.new(value.to_s)
        end

        def group_by(value)
          @group_by_value = value
        end

        private

        def validate_aggregation(sensor_name, meta_aggregation)
          sensor = Sensor::Registry[sensor_name]
          allowed = sensor.allowed_aggregations
          return if allowed.include?(meta_aggregation)

          raise ArgumentError,
                "Sensor #{sensor_name} doesn't support meta aggregation #{meta_aggregation}. " \
                  "Allowed: #{allowed.join(', ')}"
        end
      end
    end
  end
end
