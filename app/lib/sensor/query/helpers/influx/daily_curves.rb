module Sensor
  module Query
    module Helpers
      module Influx
        # The 5-minute means of some sensors for many days, in one Flux
        # program, for the detection of the charging sessions (see
        # ChargingSession::Detection). They are the same buckets that
        # Sensor::Query::Series builds for the charts, and a bucket carries the
        # end of its 5 minutes.
        #
        # A boolean like the connection of the car takes the last value of
        # its 5 minutes instead, which becomes 1 or 0 (see #aggregate).
        #
        # Each curve reads a run of consecutive days in one stream and not in
        # a stream for each day, and Ruby gives each day its buckets (see
        # #days_of). This keeps the buckets of a stream for each day, but the
        # program is much smaller (a week: 30 -> 6 streams, 161 -> 100 ms).
        class DailyCurves
          DAY = 'day'.freeze
          private_constant :DAY

          BUCKET = 5.minutes
          private_constant :BUCKET

          # The prefix of the day of the reading before a run (see
          # #state_streams)
          BEFORE = 'before:'.freeze
          private_constant :BEFORE

          # `curves` is a list of { sensor_names:, margin:, positive:, state: }.
          # The margin widens each day on both sides: a car reports its state
          # only while it is online, so a reading before midnight can belong
          # to a session after it. `positive` keeps the buckets above 0 alone,
          # so a wallbox that is idle most of the day sends few rows. `state`
          # starts the curve of each day with the last reading before it, at
          # any age, because a state holds until its next reading (see the DSL
          # `state`).
          def initialize(dates, curves)
            @dates = dates
            @curves = curves.flat_map { split(it) }
          end

          attr_reader :dates, :curves

          # { Date => { sensor_name => [[Time, value], ...] } }, sorted by time
          def call
            return {} if curves.empty? || dates.empty?

            parse(FluxProgram.query(build_flux, class_name: self.class.name, sensors: curves.flat_map { it[:sensor_names] }))
          end

          private

          # A curve of booleans and other sensors becomes two curves, because
          # a boolean needs its own aggregation (see #aggregate). A curve
          # without a margin gets 0.
          def split(curve)
            curve[:sensor_names]
              .partition { Sensor::Registry[it].unit == :boolean }
              .zip([true, false])
              .reject { |names, _| names.empty? }
              .map { |names, boolean| curve.merge(sensor_names: names, boolean:, margin: curve[:margin] || 0) }
          end

          # A boolean can come as text, for example "true" from MQTT. A
          # conversion with toFloat() fails on such a text for the whole
          # program. So a boolean
          # takes the last value of its 5 minutes, which works with each type
          # and which InfluxDB reads from its storage directly. Ruby then reads
          # the value with the rules of Sensor::Units::Boolean (see #parse). A
          # conversion in Flux reads each row and was many times slower.
          def aggregate(curve)
            return '|> aggregateWindow(every: 5m, fn: last, createEmpty: false)' if curve[:boolean]

            # The mean of an integer is a float as well
            mean = '|> aggregateWindow(every: 5m, fn: mean, createEmpty: false)'
            curve[:positive] ? "#{mean}\n  |> filter(fn: (r) => r._value > 0.0)" : mean
          end

          def build_flux
            streams =
              curves.each_with_index.flat_map do |curve, curve_index|
                predicate = SensorFilter.predicate(curve[:sensor_names])
                runs.each_with_index.map do |run, run_index|
                  range = FluxProgram.range_args(window_start(run.first, curve[:margin]), window_stop(run.last, curve[:margin]))

                  <<~FLUX
                    k#{curve_index}_#{run_index} = from(bucket: "#{FluxProgram.bucket}")
                      |> range(#{range})
                      |> filter(fn: #{predicate})
                      #{aggregate(curve)}
                      |> keep(columns: ["_time", "_value", "_field", "_measurement"])
                  FLUX
                end
              end
            streams += state_streams
            names = streams.map { it[/\A(\w+) =/, 1] }

            "#{streams.join}\n#{FluxProgram.union(names)}"
          end

          def window_start(date, margin) = Timeframe.new(date.iso8601).beginning - margin

          # The end of the window of a day. Like the chart of a day, it ends a
          # second before midnight, so its last bucket ends there too.
          def window_stop(date, margin) = (Timeframe.new(date.iso8601).ending + margin).change(usec: 0)

          # The last reading before each run of consecutive dates, for each
          # curve of a state. last() reads only the edge of its range, so the
          # range needs no limit. The days of a run find a later reading in
          # the curves of the days before them (see #hold_states).
          def state_streams
            curves.each_with_index.flat_map do |curve, curve_index|
              next [] unless curve[:state]

              runs.each_with_index.filter_map do |run, run_index|
                stop = window_start(run.first, curve[:margin])
                next if stop <= installation_time

                # The mean of the buckets is a float, so an integer reading
                # would collide with it in the union
                <<~FLUX
                  s#{curve_index}_#{run_index} = from(bucket: "#{FluxProgram.bucket}")
                    |> range(#{FluxProgram.range_args(installation_time, stop)})
                    |> filter(fn: #{SensorFilter.predicate(curve[:sensor_names])})
                    |> last()#{"\n  |> toFloat()" unless curve[:boolean]}
                    |> set(key: "#{DAY}", value: "#{BEFORE}#{run.first}")
                    |> keep(columns: ["_time", "_value", "_field", "_measurement", "#{DAY}"])
                FLUX
              end
            end
          end

          def runs = FluxProgram.runs(dates)

          def installation_time = FluxProgram.installation_time

          # Time.iso8601 is many times faster than Time.zone.parse, which
          # counts with some thousand rows for each chunk.
          def parse(rows)
            lookup = SensorFilter.lookup(curves.flat_map { it[:sensor_names] })
            points = Hash.new { |hash, day| hash[day] = Hash.new { |by_sensor, name| by_sensor[name] = [] } }

            rows.each do |row|
              sensor_names = lookup[[row['_measurement'], row['_field']]]
              value = value_of(row['_value'], sensor_names.first) if sensor_names.any?
              next unless value

              add(points, row, sensor_names, value)
            end

            result = dates.index_with { |date| points[date.iso8601].transform_values { it.sort_by(&:first) } }
            hold_states(result, points)
          end

          # The reading before a run carries its day, and a bucket goes to each
          # day whose window holds it
          def add(points, row, sensor_names, value)
            time = Time.iso8601(row['_time'])

            sensor_names.each do |name|
              next points[row[DAY]][name] << [time, value] if row[DAY]

              days_of(name, time).each { |day, stamp| points[day][name] << [stamp, value] }
            end
          end

          # [[day, time], ...] of the days whose window holds the bucket that
          # ends at the time. A margin gives a bucket to two days. The window of
          # a day ends a second before midnight (see #window_stop), so the
          # bucket at midnight ends there for the day before.
          def days_of(name, time)
            start = time - BUCKET
            windows[margins[name]].filter_map do |day, from, to|
              [day, [time, to].min] if start >= from && start < to
            end
          end

          # { margin => [[day, start, stop], ...] }
          def windows
            @windows ||= Hash.new do |hash, margin|
              hash[margin] = dates.map { [it.iso8601, window_start(it, margin), window_stop(it, margin)] }
            end
          end

          # { sensor_name => margin }
          def margins
            @margins ||= curves.flat_map { |curve| curve[:sensor_names].map { [it, curve[:margin]] } }.to_h
          end

          # Each curve of a state starts with the last reading before its
          # window: the reading before the run, or a later one from the curve of
          # a day before
          def hold_states(result, points)
            state_margins.each do |name, margin|
              runs.each { |run| hold_state(result, run, name, margin, points["#{BEFORE}#{run.first}"][name]) }
            end

            result
          end

          def hold_state(result, run, name, margin, before)
            readings = [*before, *run.flat_map { result[it].fetch(name, []) }].sort_by(&:first)

            run.each do |date|
              start = window_start(date, margin)
              last = readings.rfind { |time, _| time < start }
              result[date][name] = [last, *result[date][name]] if last
            end
          end

          # { sensor_name => margin } of the curves of a state
          def state_margins
            margins.slice(*curves.select { it[:state] }.flat_map { it[:sensor_names] })
          end

          # The value as a number. A boolean is 1.0 or 0.0, or nil for a
          # value that is no boolean.
          def value_of(raw_value, sensor_name)
            return raw_value.to_f if boolean_names.exclude?(sensor_name)

            boolean = Sensor::Units::Boolean.parse(raw_value)
            (boolean ? 1.0 : 0.0) unless boolean.nil?
          end

          def boolean_names
            @boolean_names ||= curves.select { it[:boolean] }.flat_map { it[:sensor_names] }.to_set
          end
        end
      end
    end
  end
end
