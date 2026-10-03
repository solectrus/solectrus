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
              sensor_names.index_with { [value_at(points[it], day.beginning), value_at(points[it], stop)] }
            end
          end

          private

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
            parse(FluxProgram.query(build_flux, class_name: self.class.name, sensors: sensor_names))
          end

          def build_flux
            list = streams
            names = Array.new(list.size) { "p#{it}" }

            <<~FLUX
              #{FluxProgram.source(SensorFilter.predicate(sensor_names))}
              #{list.each_with_index.map { |stream, index| "p#{index} = #{stream}" }.join("\n")}

              #{FluxProgram.union(names)}
                |> keep(columns: ["_time", "_value", "_field", "_measurement"])
            FLUX
          end

          # The streams of each run of consecutive dates, so a chunk of
          # scattered dates costs its days and not the span between them
          def streams
            FluxProgram.runs(dates).flat_map { run_streams(it) }
          end

          # The last reading before the run, the first and the last reading
          # of each day of the run, and the first reading after it
          def run_streams(run)
            days = run.map { Timeframe.new(it.iso8601) }
            first_start = days.first.beginning
            last_stop = [days.last.beginning_of_next, Time.current].min

            [
              ("source(#{FluxProgram.range_args(installation_time, first_start)}) |> last()" if first_start > installation_time),
              *days.flat_map do |day|
                range = FluxProgram.range_args(day.beginning, day.beginning_of_next)
                ["source(#{range}) |> first()", "source(#{range}) |> last()"]
              end,
              "from(bucket: \"#{FluxProgram.bucket}\") |> range(start: #{last_stop.iso8601}) |> filter(fn: sensors) |> first()",
            ].compact
          end

          def parse(rows)
            lookup = SensorFilter.lookup(sensor_names)
            result = sensor_names.index_with { [] }

            rows.each do |row|
              names = lookup[[row['_measurement'], row['_field']]]
              next if names.empty?

              reading = [Time.iso8601(row['_time']), row['_value']]
              names.each { result[it] << reading }
            end

            result
          end

          def installation_time = FluxProgram.installation_time
        end
      end
    end
  end
end
