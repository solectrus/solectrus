module Sensor
  module Query
    module Influx
      # Calculates statistical aggregations (min, max, avg) directly from InfluxDB
      # Used for: Stats pages, performance analysis
      class Aggregation < Base
        protected

        def create_data_instance(raw_data, timeframe)
          # Convert aggregation format to single format with array keys
          # From: { sensor => { min: x, max: y, avg: z } }
          # To:   { [sensor, :min] => x, [sensor, :max] => y, [sensor, :avg] => z }
          converted_data = {}

          raw_data[:payload].each do |sensor_name, aggregations|
            aggregations.each do |agg_type, value|
              converted_data[[sensor_name, agg_type]] = value
            end
          end

          Sensor::Data::Single.new(converted_data, timeframe:)
        end

        private

        def build_flux_query
          <<~FLUX
            commonQuery = () =>
              #{from_bucket}
              |> #{range(start: timeframe.beginning, stop: timeframe.ending)}
              |> #{filter}
              |> aggregateWindow(every: 5m, fn: mean)

            minQuery = commonQuery()
              |> min()
              |> set(key: "operation", value: "min")
              |> keep(columns: ["_value", "operation", "_field", "_measurement"])

            maxQuery = commonQuery()
              |> max()
              |> set(key: "operation", value: "max")
              |> keep(columns: ["_value", "operation", "_field", "_measurement"])

            avgQuery = commonQuery()
              |> mean()
              |> set(key: "operation", value: "avg")
              |> keep(columns: ["_value", "operation", "_field", "_measurement"])

            union(tables: [minQuery, maxQuery, avgQuery])
              |> pivot(rowKey:["_field", "_measurement"], columnKey: ["operation"], valueColumn: "_value")
          FLUX
        end

        def parse_flux_result(flux_result)
          result = {}

          flux_result.each do |table|
            table.records.each do |record|
              sensor =
                find_sensor_by_measurement_and_field(
                  record.values['_measurement'],
                  record.values['_field'],
                )
              next unless sensor

              # Initialize sensor hash if not exists
              result[sensor] ||= {}

              # Extract aggregation values from pivoted columns
              result[sensor][:min] = record.values['min']
              result[sensor][:max] = record.values['max']
              result[sensor][:avg] = record.values['avg']
            end
          end

          # Ensure all requested sensors have entries, even if no data was found
          ensure_all_sensors_present(result)

          result
        end

        def ensure_all_sensors_present(result)
          sensor_names.each do |sensor_name|
            # Add missing sensors with nil values for all aggregation types
            unless result.key?(sensor_name)
              result[sensor_name] = { min: nil, max: nil, avg: nil }
            end
          end
        end

        def validate_timeframe!
          return unless timeframe.now?

          raise ArgumentError, 'Timeframe must have a beginning and ending'
        end
      end
    end
  end
end
