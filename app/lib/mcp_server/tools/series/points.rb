module McpServer
  module Tools
    class Series < Base
      # Serialises one sensor's {time => value} hash into the curve a client
      # receives: a bare list of values on a stated axis, rather than a list of
      # {time, value} objects.
      #
      # Why the axis is stated once instead of repeated per point: a point cost
      # ~50 bytes, of which ~33 were an ISO timestamp that `start` and
      # `step_seconds` already determine. One sensor over one day at "5m" is
      # 288 points - 14.8 kB of which 9.5 kB was the same timestamp written 288
      # times, each differing from its neighbour by five minutes. The client
      # pays that in context, and a curve is the largest thing this server
      # returns.
      module Points
        # The raster a series sits on: how wide one bucket is, and where the
        # window begins and ends. Together they decide both where a point is
        # labelled and whether its bucket is complete, which is why they travel
        # as one value rather than as three arguments that could be passed
        # apart.
        Grid = Data.define(:interval, :beginning, :ending)
        public_constant :Grid

        module_function

        # The curve as an axis plus a list of values, ready to splat into the
        # per-sensor entry.
        #
        # `start` is the window's first bucket, `step_seconds` the bucket
        # width, so the time of values[i] is start + i * step_seconds.
        # `indices` appears only where that arithmetic does not hold - with
        # include_nulls: false, where the empty buckets are gone and the
        # remaining ones keep their place on the grid through their index. An
        # empty bucket that IS sent is an explicit null, distinct from a
        # measured 0.
        def build(data, sensor_name, aggregation, unit:, include_nulls:, grid: nil)
          buckets = raw(data, sensor_name, aggregation) || {}
          buckets = buckets.compact unless include_nulls

          entries =
            buckets.sort.map! do |time, value|
              [grid_end(time, grid&.interval), normalize_value(value, unit)]
            end

          axis(entries, grid)
        end

        # The axis is stated even when no bucket carried a value: the timeframe
        # and the resolution fix the grid, so an empty curve still knows where
        # it would have started. Leaving it out made the one response a client
        # cannot interpret - `values: []` with nothing to say what the values
        # would have meant - and forced a special case on the reader for the
        # case that needs it least.
        def axis(entries, grid)
          start = grid_start(grid) || entries.first&.first
          return { point_count: 0, values: [] } unless start

          {
            start: start.iso8601,
            **step_note(grid),
            point_count: entries.size,
            **index_note(entries, start, grid&.interval),
            **partial_note(entries, grid),
            values: entries.map(&:last),
          }
        end

        def step_note(grid)
          grid&.interval ? { step_seconds: grid.interval.to_i } : {}
        end

        # The grid position of each value, sent only where it is not the
        # position in `values` anyway - the common case, since include_nulls
        # defaults to true and a full grid indexes itself.
        def index_note(entries, start, step)
          indices = offsets(entries, start, step)
          return {} if indices.each_with_index.all? { |index, i| index == i }

          { indices: }
        end

        # How many steps each bucket sits from `start`. Without an interval
        # there is no axis to count along, and the single entry that can occur
        # then sits at zero.
        def offsets(entries, start, step)
          return Array.new(entries.size, 0) unless step

          entries.map { |at, _| ((at - start) / step).round }
        end

        # The END of the window's FIRST bucket, whether or not it carries a
        # value - the fixed zero of the axis.
        #
        # Anchoring on the first value instead is off by however many empty
        # buckets precede it, and that shifts per sensor and per include_nulls
        # setting. Two sensors in one response would then carry two axes for
        # one grid, and the same curve would read differently depending on
        # whether its empty buckets were sent.
        #
        # The first bucket is the one that ENDS strictly after the window
        # opens, so a window opening exactly on a tick still gets the bucket
        # that follows it, never the one that already closed.
        def grid_start(grid)
          return unless grid&.interval && grid.beginning

          base = grid.beginning.beginning_of_day
          steps = ((grid.beginning - base) / grid.interval).floor + 1

          base + (steps * grid.interval)
        end

        # Positions in `values` whose bucket the window cuts into. Positions
        # rather than grid indices, so one rule covers both shapes: whatever
        # `indices` does, this always points into the array beside it.
        #
        # `partial` qualifies a value; an empty bucket has none to qualify.
        # Without that guard a running period marked every bucket still ahead of
        # now - 16 of them by breakfast, all saying "this null is incomplete".
        def partial_note(entries, grid)
          at =
            entries.each_index.select do |i|
              time, value = entries[i]
              !value.nil? && incomplete?(time, grid)
            end

          at.empty? ? {} : { partial_at: at }
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
