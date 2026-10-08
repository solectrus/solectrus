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
        # A wrong reading, like a 0 of an offline car, is left out (see
        # Sensor::MeterReadings). A second query then reads the readings
        # around it (see #fetch_points).
        #
        # Influx::DailyBatch runs it next to its other programs, so the diffs
        # cost no extra round trip.
        class DailyDiffs
          # How far the filter on the value reads before and after a run of
          # days (see #run_streams)
          EDGE_WINDOW = 30.days
          private_constant :EDGE_WINDOW

          def initialize(dates, sensor_names)
            @dates = dates
            @sensor_names = sensor_names.select { Sensor::Config.configured?(it) }
          end

          attr_reader :dates, :sensor_names

          # { Date => { sensor_name => value or nil } }: the increase over the
          # day, or nil without a reading
          def call
            bounds.transform_values do |by_sensor|
              by_sensor.transform_values do |(start_value, end_value)|
                [end_value - start_value, 0].max if start_value && end_value
              end
            end
          end

          # { Date => { sensor_name => [start_value, end_value] } }: the
          # reading at the start and at the end of the day, each nil without a
          # reading. The running day ends now instead of extrapolating into the
          # future.
          def bounds
            return {} if sensor_names.empty? || dates.empty?

            points = fetch_points

            dates.index_with do |date|
              day = Timeframe.new(date.iso8601)
              stop = [day.beginning_of_next, Time.current].min
              sensor_names.index_with { [value_at(points[it], day.beginning), value_at(points[it], stop, first_stands_in: false)] }
            end
          end

          private

          # The reading at the time, interpolated between the readings around
          # it. A reading exactly at the time counts as the one before it.
          #
          # Before the first reading, the first reading stands in at the start
          # of a day, so the day of the first reading keeps its increase. At
          # the end of a day before the first reading, the meter had not read
          # yet, so the day has no value and not an increase of 0.
          def value_at(points, time, first_stands_in: true)
            return if time <= installation_time

            before = reading_before(points, time)
            return unless before || first_stands_in

            interpolate(before, reading_after(points, time), time)
          end

          def reading_before(points, time) = points.select { |t, _| t <= time }.max_by(&:first)

          def reading_after(points, time) = points.select { |t, _| t > time }.min_by(&:first)

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
          #
          # The edges of the ranges, which InfluxDB reads from its storage directly.
          # A wrong reading at an edge hides the readings beside it, so only then
          # a second program reads the edges of its sensors above 0 (see
          # #run_streams). A day of a car that sends no 0 thus costs no more.
          def fetch_points
            points = read_points(sensor_names, 'source')
            wrong = sensor_names.select { points[it].size > plausible(points[it]).size }
            points.merge!(read_points(wrong, 'valid')) if wrong.any?

            points.to_h { |name, readings| [name, plausible(readings)] }
          end

          def read_points(names, reader)
            flux = build_flux(names, reader)
            parse(FluxProgram.query(flux, class_name: self.class.name, sensors: names), names)
          end

          def build_flux(names, reader)
            list = streams(reader)
            stream_names = Array.new(list.size) { "p#{it}" }

            <<~FLUX
              #{FluxProgram.source(SensorFilter.predicate(names))}
              valid = (start, stop) => source(start, stop) |> filter(fn: (r) => float(v: r._value) > 0.0)
              #{list.each_with_index.map { |stream, index| "p#{index} = #{stream}" }.join("\n")}

              #{FluxProgram.union(stream_names)}
                |> keep(columns: ["_time", "_value", "_field", "_measurement"])
            FLUX
          end

          # The streams of each run of consecutive dates, so a chunk of
          # scattered dates costs its days and not the span between them
          def streams(reader)
            FluxProgram.runs(dates).flat_map { run_streams(it, reader) }
          end

          # The last reading before the run, the first and the last reading of
          # each day of the run, and the first reading after it. The reader
          # `valid` reads the readings above 0 alone. Its filter on the value
          # reads each row of its range, which is cheap for a day. Before and
          # after the run, it reads EDGE_WINDOW only, and a reading beyond comes
          # from the open range without the filter.
          def run_streams(run, reader)
            days = run.map { Timeframe.new(it.iso8601) }
            first_start = days.first.beginning
            last_stop = [days.last.beginning_of_next, Time.current].min

            [
              *before_run(first_start, reader),
              *days.flat_map do |day|
                range = FluxProgram.range_args(day.beginning, day.beginning_of_next)
                ["#{reader}(#{range}) |> first()", "#{reader}(#{range}) |> last()"]
              end,
              *after_run(last_stop, reader),
            ]
          end

          def before_run(first_start, reader)
            return [] if first_start <= installation_time

            open = "source(#{FluxProgram.range_args(installation_time, first_start)}) |> last()"
            return [open] if reader == 'source'

            ["valid(#{FluxProgram.range_args([first_start - EDGE_WINDOW, installation_time].max, first_start)}) |> last()", open]
          end

          def after_run(last_stop, reader)
            open = "from(bucket: \"#{FluxProgram.bucket}\") |> range(start: #{last_stop.iso8601}) |> filter(fn: sensors) |> first()"
            return [open] if reader == 'source'

            ["valid(#{FluxProgram.range_args(last_stop, last_stop + EDGE_WINDOW)}) |> first()", open]
          end

          def parse(rows, names)
            lookup = SensorFilter.lookup(names)
            result = names.index_with { [] }

            rows.each do |row|
              row_names = lookup[[row['_measurement'], row['_field']]]
              next if row_names.empty?

              reading = [Time.iso8601(row['_time']), row['_value']]
              row_names.each { result[it] << reading }
            end

            result
          end

          # The plausible readings, sorted by time
          def plausible(readings) = Sensor::MeterReadings.new(readings).call

          def installation_time = FluxProgram.installation_time
        end
      end
    end
  end
end
