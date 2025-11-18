module Sensor
  module Query
    module Helpers
      module Sql
        # DSL Builder for Sensor::Query::Helpers::Sql::Total to create fluent API for sensor requests
        #
        # Usage:
        #   builder = DslBuilder.new
        #   builder.sum :house_power, :sum
        #   builder.group_by :month
        class DslBuilder
          def initialize
            @sensor_requests = []
            @group_by_value = nil
          end

          attr_reader :sensor_requests, :group_by_value

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

          # DSL method for configuration
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
end
