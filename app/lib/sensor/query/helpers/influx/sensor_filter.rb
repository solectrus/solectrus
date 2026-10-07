module Sensor
  module Query
    module Helpers
      module Influx
        # The selection of sensors in a Flux program, and the way back from a
        # row to its sensor (see Base, DailyCurves, DailyDiffs and
        # ChargingSession::Detection)
        module SensorFilter
          # The Flux predicate that selects the given sensors, with the fields
          # of a measurement grouped
          def self.predicate(sensor_names)
            grouped =
              sensor_names.each_with_object(Hash.new { |h, k| h[k] = [] }) do |name, result|
                measurement = Sensor::Config.measurement(name)
                field = Sensor::Config.field(name)
                result[measurement] << field if measurement && field
              end

            return '(r) => false' if grouped.empty?

            conditions =
              grouped.map do |measurement, fields|
                field_conditions = fields.map { %(r["_field"] == "#{it}") }.join(' or ')
                %(r["_measurement"] == "#{measurement}" and (#{field_conditions}))
              end

            "(r) => #{conditions.join(' or ')}"
          end

          # { [measurement, field] => [sensor_name, ...] }, to find the sensors
          # of a row. Two sensors can read the same field.
          def self.lookup(sensor_names)
            sensor_names.group_by { [Sensor::Config.measurement(it), Sensor::Config.field(it)] }.tap { it.default = [].freeze }
          end
        end
      end
    end
  end
end
