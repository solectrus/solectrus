module Sensor
  module Query
    module Influx
      # Calculates energy integrals (Wh values) directly from InfluxDB
      # Used for: Summarizer job and "hours" timeframes
      class Integral < Base
        protected

        def create_data_instance(raw_data, timeframe)
          Sensor::Data::Single.new(raw_data[:payload], timeframe:)
        end

        def build_flux_query
          <<~FLUX
            #{from_bucket}
            |> #{range(start: timeframe.beginning, stop: timeframe.ending)}
            |> #{filter}
            |> integral(unit: 1h)
          FLUX
        end

        private

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

              # Integral values are single energy values in Wh
              result[sensor] = record.values['_value']
            end
          end

          result
        end

        def validate_timeframe!
          return unless timeframe.now?

          raise ArgumentError, 'Timeframe must have a beginning and ending'
        end

        def validate_sensor_names!
          sensor_names.each do |sensor_name|
            next if Sensor::Registry[sensor_name].unit == :watt

            raise ArgumentError,
                  "Invalid sensor name: #{sensor_name}. Only sensors with unit :watt allowed."
          end
        end
      end
    end
  end
end
