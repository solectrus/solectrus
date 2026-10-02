module Sensor
  module Query
    module Helpers
      module Influx
        # The daily increase of meters, like a car odometer, that report far
        # less often than once a day, for many days in one Flux program.
        #
        # The increase of a day is the reading at the start of the next day
        # minus the reading at the start of the day. Each reading at such a
        # boundary is interpolated linearly between the last reading at or
        # before it and the first reading after it. A day without a reading
        # thus gets its share of the distance between the readings around it.
        # The boundary of the next day makes the diffs of consecutive days
        # telescope: their sum is the increase over the whole range.
        #
        # For a run of consecutive days, the points around each boundary are
        # among the first and the last reading of each day, plus the last
        # reading before the run and the first reading after it. One query
        # fetches exactly these points.
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
              day = Timeframe.new(date.iso8601)
              sensor_names.index_with { diff(points[it], day) }
            end
          end

          private

          # The increase over the day, or nil without a reading. The running
          # day ends now instead of extrapolating into the future.
          def diff(points, day)
            start_value = value_at(points, day.beginning)
            end_value = value_at(points, [day.beginning_of_next, Time.current].min)
            [end_value - start_value, 0].max if start_value && end_value
          end

          # The reading at the time, interpolated between the readings around
          # it. A reading exactly at the time counts as the one before it.
          def value_at(points, time)
            return if time <= installation_time

            before = points.select { |t, _| t <= time }.max_by(&:first)
            after = points.select { |t, _| t > time }.min_by(&:first)
            interpolate(before, after, time)
          end

          def interpolate(before, after, time)
            # Without an earlier reading, the first reading stands in. A
            # meter cannot have read more before, so the first day keeps its
            # increase.
            return after&.last unless before

            # Without a later reading, the last reading stands in. For a
            # meter this only underestimates.
            before_time, before_value = before
            return before_value if after.nil? || before_time == time

            after_time, after_value = after
            before_value + ((after_value - before_value) * (time - before_time).fdiv(after_time - before_time))
          end

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
