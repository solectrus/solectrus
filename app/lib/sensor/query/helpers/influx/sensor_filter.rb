module Sensor
  module Query
    module Helpers
      module Influx
        # The selection of sensors in a hand-built Flux program, and the way
        # back from a row to its sensor (see DailyCurves, DailyDiffs and
        # ChargingSession::Detection)
        module SensorFilter
          # The Flux predicate that selects the given sensors
          def self.predicate(sensor_names)
            conditions =
              sensor_names.filter_map do |name|
                measurement = Sensor::Config.measurement(name)
                field = Sensor::Config.field(name)
                %((r["_measurement"] == "#{measurement}" and r["_field"] == "#{field}")) if measurement && field
              end

            conditions.empty? ? '(r) => false' : "(r) => #{conditions.join(' or ')}"
          end

          # { [measurement, field] => sensor_name }, to find the sensor of a row
          def self.lookup(sensor_names)
            sensor_names.index_by { [Sensor::Config.measurement(it), Sensor::Config.field(it)] }
          end
        end
      end
    end
  end
end
