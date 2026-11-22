module Sensor
  module Query
    module Helpers
      module Influx
        # DSL Builder for Sensor::Query::Helpers::Influx::Total to create fluent API
        # for sensor requests with different aggregations
        #
        # The base_aggregation parameter determines which Flux function to use,
        # allowing efficient query grouping when multiple sensors use the same
        # base aggregation function.
        #
        # Usage:
        #   builder = DslBuilder.new
        #   builder.sum :house_power         # Defaults: base_aggregation = :sum
        #   builder.avg :case_temp, :avg     # Explicit base_aggregation
        #
        # Compatible with Sensor::Query::Sql DSL for consistency
        class DslBuilder
          def initialize
            @sensor_requests = []
          end

          attr_reader :sensor_requests

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

          # The value of a sensor as its trend aggregates it, like the SQL
          # builder does. A weighted trend counts each day by its weight,
          # and the hours of InfluxDB have no days to weight, so it takes the
          # plain aggregation.
          def trend(sensor_name)
            public_send(Sensor::Registry[sensor_name].trend_aggregation, sensor_name)
          end

          private

          def validate_aggregation(sensor_name, aggregation)
            sensor = Sensor::Registry[sensor_name]
            allowed = sensor.allowed_aggregations
            return if allowed.include?(aggregation)

            raise ArgumentError,
                  "Sensor #{sensor_name} doesn't support aggregation #{aggregation}. " \
                    "Allowed: #{allowed.join(', ')}"
          end
        end
      end
    end
  end
end
