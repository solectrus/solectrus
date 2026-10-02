module Sensor
  module Query
    module Helpers
      module Influx
        # The 5-minute means of some sensors for many days, in one Flux
        # program, for the detection of the charging sessions (see
        # ChargingSession::Detection). They are the same buckets that
        # Sensor::Query::Series builds for the charts, and a bucket carries the
        # end of its 5 minutes. A boolean like the connection of the car
        # becomes 0 or 1.
        class DailyCurves
          DAY = 'day'.freeze
          private_constant :DAY

          # `curves` is a list of { sensor_names:, margin: }. The margin
          # widens each day on both sides: a car reports its state only while
          # it is online, so a reading before midnight can belong to a
          # session after it.
          def initialize(dates, curves)
            @dates = dates
            @curves = curves.reject { it[:sensor_names].empty? }
          end

          attr_reader :dates, :curves

          # { Date => { sensor_name => [[Time, value], ...] } }, sorted by time
          def call
            return {} if curves.empty? || dates.empty?

            flux = build_flux
            rows =
              ActiveSupport::Notifications.instrument(
                'query.sensor_influx',
                class: self.class.name,
                query: flux,
                sensors: curves.flat_map { it[:sensor_names] },
              ) { ::Influx.query(flux) }

            parse(rows)
          end

          private

          def build_flux
            streams =
              curves.each_with_index.flat_map do |curve, curve_index|
                predicate = SensorFilter.predicate(curve[:sensor_names])

                dates.map.with_index do |date, index|
                  <<~FLUX
                    k#{curve_index}_#{index} = from(bucket: "#{bucket}")
                      |> range(#{range_args(date, curve[:margin] || 0)})
                      |> filter(fn: #{predicate})
                      |> toFloat()
                      |> aggregateWindow(every: 5m, fn: mean, createEmpty: false)
                      |> set(key: "#{DAY}", value: "#{date}")
                      |> keep(columns: ["_time", "_value", "_field", "_measurement", "#{DAY}"])
                  FLUX
                end
              end
            names = streams.map { it[/\A(\w+) =/, 1] }

            "#{streams.join}\n#{names.one? ? names.first : "union(tables: [#{names.join(', ')}])"}"
          end

          def range_args(date, margin)
            timeframe = Timeframe.new(date.iso8601)

            "start: #{(timeframe.beginning - margin).iso8601}, stop: #{(timeframe.ending + margin).iso8601}"
          end

          # Time.iso8601 is many times faster than Time.zone.parse, which
          # counts with some thousand rows for each chunk.
          def parse(rows)
            lookup = SensorFilter.lookup(curves.flat_map { it[:sensor_names] })
            result = dates.index_with { Hash.new { |hash, key| hash[key] = [] } }

            rows.each do |row|
              sensor_name = lookup[[row['_measurement'], row['_field']]]
              series = result[Date.iso8601(row[DAY])] if sensor_name
              series[sensor_name] << [Time.iso8601(row['_time']), row['_value'].to_f] if series
            end

            result.transform_values { |by_sensor| by_sensor.transform_values { it.sort_by(&:first) }.to_h }
          end

          def bucket
            Rails.configuration.x.influx.bucket
          end
        end
      end
    end
  end
end
