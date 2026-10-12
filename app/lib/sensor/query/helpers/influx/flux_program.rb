module Sensor
  module Query
    module Helpers
      module Influx
        # The parts of a hand-built Flux program that unions one stream per
        # day or per period (see DailyBatch, DailyCurves, DailyDiffs and
        # ChargingSession::Detection)
        module FluxProgram
          # Runs the program with the event of a per-day query, so it stays
          # visible to log and APM subscribers
          def self.query(flux, class_name:, sensors:)
            ActiveSupport::Notifications.instrument('query.sensor_influx', class: class_name, query: flux, sensors:) do
              ::Influx.query(flux)
            end
          end

          # Naming the selection once keeps the program small: it is by far
          # its longest part and would otherwise be repeated for every stream.
          def self.source(predicate)
            <<~FLUX
              sensors = #{predicate}
              source = (start, stop) => from(bucket: "#{bucket}")
                |> range(start: start, stop: stop)
                |> filter(fn: sensors)
            FLUX
          end

          # The arguments of range() or source()
          def self.range_args(start, stop)
            "start: #{start.iso8601}, stop: #{stop.iso8601}"
          end

          # Flux knows no union of a single table, so a lone stream is
          # yielded as it is.
          def self.union(names)
            names.one? ? names.first : "union(tables: [#{names.join(', ')}])"
          end

          # The start of the data, the earliest start of a range
          def self.installation_time
            Rails.configuration.x.installation_date.beginning_of_day
          end

          # The runs of consecutive days among the dates, sorted
          def self.runs(dates)
            dates.sort.slice_when { |date, next_date| next_date > date.next_day }.to_a
          end

          def self.bucket
            Rails.configuration.x.influx.bucket
          end
        end
      end
    end
  end
end
