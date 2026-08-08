module McpServer
  module Tools
    class Series < Base
      # Serialises one sensor's {time => value} hash into the point list a
      # client receives.
      module Points
        # The raster a series sits on: how wide one bucket is, and where the
        # window begins and ends. Together they decide both where a point is
        # labelled and whether its bucket is complete, which is why they travel
        # as one value rather than as three arguments that could be passed
        # apart.
        Grid = Data.define(:interval, :beginning, :ending)
        public_constant :Grid

        module_function

        # Sorted {time, value} points. An empty bucket is a point without a
        # value; dropping those is what makes a sporadically written sensor
        # affordable, and it stays unambiguous because the remaining points sit
        # on the same grid - a missing timestamp reads exactly like an explicit
        # null.
        def build(data, sensor_name, aggregation, unit:, include_nulls:, grid: nil)
          buckets = raw(data, sensor_name, aggregation) || {}
          buckets = buckets.compact unless include_nulls

          buckets.sort.map! do |time, value|
            at = grid_end(time, grid&.interval)
            rounded = normalize_value(value, unit)

            {
              time: at.iso8601,
              value: rounded,
              # `partial` qualifies a value; an empty bucket has none to
              # qualify. Without that guard every bucket still ahead of now
              # carried the marker on a running period - 16 of them by
              # breakfast, all saying "this null is incomplete".
              **(!rounded.nil? && incomplete?(at, grid) ? { partial: true } : {}),
            }
          end
        end

        # `data` exposes an accessor for every requested sensor: raw sensors via
        # Data::Series, derived sensors via the singleton accessor that
        # process_calculated_sensors installs (house_power - sum(custom_power),
        # autarky, ...). A raw sensor without any data returns nil.
        def raw(data, sensor_name, aggregation)
          return unless data.respond_to?(sensor_name)

          data.public_send(sensor_name, aggregation, aggregation)
        end

        # A bucket's end on the grid every other bucket sits on.
        #
        # aggregateWindow clips its FINAL bucket at the range stop, so the last
        # point of a window arrives off-grid whenever the stop is not a grid
        # tick - which is both of the stops this tool ever passes. A calendar
        # day stops at 23:59:59, so a day at "1h" read 01:00, 02:00, ..., 23:00,
        # 23:59:59. A window still running stops at now, so "P2H" at "1h" read
        # 05:00, 06:00, 06:44:29. Either way a client reading the points as a
        # raster can only take the last one for a bucket of its own.
        #
        # Rounding UP to the next tick states what the bucket covers rather than
        # how far it happened to be filled, and it needs no special case: a
        # point already on the grid rounds to itself. Ticks are counted from
        # local midnight, which every offered resolution divides evenly, so they
        # follow local time like the buckets themselves.
        #
        # Left to the serializer rather than fixed in Timeframe: the stop is
        # what every UI chart queries with too, and a global shift would move
        # every one of them for an MCP presentation detail.
        def grid_end(time, interval)
          return time unless interval

          base = time.beginning_of_day
          steps = ((time - base) / interval).ceil

          base + (steps * interval)
        end

        # Whether the window cuts into this bucket, so it holds less
        # measurement than a full one and must not be compared with the rest.
        # The same signal get_ranking gives for a period the timeframe cuts
        # into, and for the same reason: the value is smaller for having been
        # cut, not for having measured less.
        #
        # Both edges, because both get cut. A rolling window ("P2H" at 07:42)
        # opens mid-bucket as surely as it closes mid-bucket, and the opening
        # one is the easier of the two to misread - it sits at the start of the
        # curve, where a client looks for a baseline.
        def incomplete?(grid_end, grid)
          return false unless grid&.interval

          (grid.ending.present? && grid_end > exclusive_end(grid.ending)) ||
            (grid.beginning.present? && (grid_end - grid.interval) < grid.beginning)
        end

        # Timeframe#ending is the last NANOSECOND of the period, so a calendar
        # day ends at 23:59:59.999999999 and its final bucket, labelled with the
        # next midnight, compares as reaching past it - marking a bucket that is
        # in fact complete. Rounding the fraction up gives the exclusive end the
        # comparison actually wants, and leaves a whole-second end (the "now" a
        # rolling window stops at) exactly where it is.
        def exclusive_end(ending)
          ending.ceil
        end

        # Rounded by the unit policy like every other serialized value, then
        # stripped of a signed negative zero: Flux can hand back a -0.0 (e.g. a
        # sensor sitting at 0 around midday), and rounding a small negative
        # value can produce one too. Neither should reach the JSON output.
        def normalize_value(value, unit)
          rounded = McpServer::Precision.round(value, unit)
          return 0.0 if rounded.is_a?(Float) && rounded.zero?

          rounded
        end
      end
    end
  end
end
