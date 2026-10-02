module Sensor
  module Query
    module Helpers
      module Influx
        # The interpolated daily diff of sparse monotonic sensors, like a car
        # odometer, for many days in one Flux program (see
        # Sensor::Query::InterpolatedDiff).
        #
        # A day needs the last reading at or before each of its two
        # boundaries and the first reading after them. For a run of
        # consecutive days, these are among the first and the last reading of
        # each day, plus the last reading before the run and the first
        # reading after it. One query
        # fetches exactly these points, and InterpolatedDiff interpolates from
        # them. The per-day lookups it replaces cost two round trips for each
        # day and sensor.
        #
        # Influx::DailyBatch runs it next to its other programs, so the diffs
        # cost no extra round trip.
        class DailyDiffs
          def initialize(dates, sensor_names)
            @dates = dates
            @sensor_names = sensor_names.select { Sensor::Config.configured?(it) }
          end

          attr_reader :dates, :sensor_names

          # { Date => { sensor_name => value or nil } }
          def call
            return {} if sensor_names.empty? || dates.empty?

            points = fetch_points

            dates.index_with do |date|
              timeframe = Timeframe.new(date.iso8601)

              sensor_names.index_with do |name|
                InterpolatedDiff.call(sensor_name: name, timeframe:, points: points[name])
              end
            end
          end

          private

          # { sensor_name => [[Time, value], ...] }
          def fetch_points
            flux = build_flux
            rows =
              ActiveSupport::Notifications.instrument(
                'query.sensor_influx',
                class: self.class.name,
                query: flux,
                sensors: sensor_names,
              ) { ::Influx.query(flux) }

            parse(rows)
          end

          def build_flux
            list = streams
            names = Array.new(list.size) { "p#{it}" }

            <<~FLUX
              sensors = #{SensorFilter.predicate(sensor_names)}
              source = (start, stop) => from(bucket: "#{bucket}")
                |> range(start: start, stop: stop)
                |> filter(fn: sensors)

              #{list.each_with_index.map { |stream, index| "p#{index} = #{stream}" }.join("\n")}

              union(tables: [#{names.join(', ')}])
                |> keep(columns: ["_time", "_value", "_field", "_measurement"])
            FLUX
          end

          # The streams of each run of consecutive dates, so a chunk of
          # scattered dates costs its days and not the span between them
          def streams
            dates.sort.slice_when { |date, next_date| next_date > date.next_day }.flat_map { run_streams(it) }
          end

          # The last reading before the run, the first and the last reading
          # of each day of the run, and the first reading after it
          def run_streams(run)
            days = run.map { Timeframe.new(it.iso8601) }
            first_start = days.first.beginning
            last_stop = [days.last.beginning_of_next, Time.current].min

            [
              ("source(start: #{iso(installation_time)}, stop: #{iso(first_start)}) |> last()" if first_start > installation_time),
              *days.flat_map do |day|
                range = "start: #{iso(day.beginning)}, stop: #{iso(day.beginning_of_next)}"
                ["source(#{range}) |> first()", "source(#{range}) |> last()"]
              end,
              "from(bucket: \"#{bucket}\") |> range(start: #{iso(last_stop)}) |> filter(fn: sensors) |> first()",
            ].compact
          end

          def parse(rows)
            lookup = SensorFilter.lookup(sensor_names)
            result = sensor_names.index_with { [] }

            rows.each do |row|
              name = lookup[[row['_measurement'], row['_field']]]
              result[name] << [Time.iso8601(row['_time']), row['_value']] if name
            end

            result
          end

          def installation_time
            Rails.configuration.x.installation_date.beginning_of_day
          end

          def iso(time)
            time.utc.iso8601
          end

          def bucket
            Rails.configuration.x.influx.bucket
          end
        end
      end
    end
  end
end
