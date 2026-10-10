module Sensor
  module Query
    module Helpers
      module Influx
        # The daily min, max and avg of the sensors of a state, like the state
        # of charge of a car, for many days in one Flux program.
        #
        # A state holds until its next reading, at any age (see the DSL
        # `state`). A parked car can send nothing for a day, and a car sends
        # often while it drives or charges. So the values come from the
        # 5-minute means of the day (see DailyCurves), and a bucket without a
        # reading holds the value of the bucket before it. The first buckets
        # of a day hold the last reading before the day. Each bucket thus
        # counts the same, like the chart of the day shows the state.
        #
        # A day before the first reading has no values. The running day ends
        # now, so the buckets of the future do not count.
        class DailyStates
          BUCKET = DailyCurves::BUCKET
          private_constant :BUCKET

          def initialize(dates, sensor_names)
            @dates = dates
            @sensor_names = sensor_names.select { Sensor::Config.configured?(it) }
            # The values computed once, also when two threads ask for them
            # (see DailyBatch and Sensor::SummaryBuilder)
            @values = Concurrent::Delay.new { @sensor_names.empty? || @dates.empty? ? {} : compute }
          end

          attr_reader :dates, :sensor_names

          # { Date => { sensor_name => { min:, max:, avg: } } }, each value nil
          # without a reading
          def call = @values.value!

          private

          def compute
            curves = DailyCurves.new(dates, [{ sensor_names:, state: true }]).call

            dates.index_with do |date|
              sensor_names.index_with { aggregate(date, curves.dig(date, it) || []) }
            end
          end

          def aggregate(date, readings)
            values = bucket_values(date, readings)
            return { min: nil, max: nil, avg: nil } if values.empty?

            { min: values.min, max: values.max, avg: values.sum.fdiv(values.size) }
          end

          # The value of each bucket of the day up to now, from the first one
          # with a value on
          def bucket_values(date, readings)
            day = Timeframe.new(date.iso8601)
            start = day.beginning
            stop = [day.ending, Time.current].min
            return [] if stop <= start

            held = readings.rfind { |time, _| time <= start }&.last
            means = bucket_means(readings, start)

            Array.new(((stop - start) / BUCKET).ceil) { |index| held = means.fetch(index, held) }.compact
          end

          # { index => mean } of the buckets of the day. A bucket carries the
          # end of its 5 minutes, and the last bucket of a day ends a second
          # before midnight (see DailyCurves#window_stop).
          def bucket_means(readings, start)
            readings.each_with_object({}) do |(time, value), means|
              means[((time - start) / BUCKET).ceil - 1] = value if time > start
            end
          end
        end
      end
    end
  end
end
