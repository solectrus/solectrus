module Sensor
  module Query
    # Linearly interpolates the value of a (typically monotonic) sensor at
    # a single point in time, using the surrounding known points pulled
    # straight from InfluxDB.
    #
    # The Flux query returns at most two records (the bracketing points)
    # regardless of the sensor's overall point count or recording cadence,
    # which keeps it cheap even for series with millions of raw samples.
    # Caching, instrumentation, and the "cache forever for past results"
    # policy are inherited from Helpers::Influx::Base.
    #
    # `points` are known [Time, value] pairs around the target time that the
    # caller has already fetched (see Helpers::Influx::DailyDiffs). They must
    # hold the last point at or before the target time and the first point
    # after it. With them, no query runs.
    class InterpolatedValue < Helpers::Influx::Base
      def initialize(sensor_name, target_time, points: nil)
        super([sensor_name], nil)
        @target_time = target_time
        @points = points
      end

      def call
        return if available_sensors.empty?
        return if target_time <= installation_time

        interpolate(*bracket(points || fetch_points))
      end

      private

      attr_reader :target_time, :points

      # A midnight of a past day is cached forever. The running day ends at
      # "now", a new time on each call, so a cache entry for it would never be
      # read again and would never expire.
      def fetch_points
        @cache_options = cache_options(stop: target_time) if target_time <= Time.current.beginning_of_day
        parse(query(flux_query))
      end

      def installation_time
        Rails.configuration.x.installation_date.beginning_of_day
      end

      def flux_query
        iso = target_time.utc.iso8601
        start = installation_time.utc.iso8601
        [
          from_bucket,
          "|> range(start: #{start}, stop: #{iso})",
          "|> #{filter}",
          '|> keep(columns: ["_time", "_value"])',
          '|> last(column: "_time")',
          '|> yield(name: "before")',
          '',
          from_bucket,
          "|> range(start: #{iso})",
          "|> #{filter}",
          '|> keep(columns: ["_time", "_value"])',
          '|> first(column: "_time")',
          '|> yield(name: "after")',
        ].join("\n")
      end

      def parse(flux_result)
        # Influx.query hands back plain rows, flattened across the two yields
        flux_result.map do |record|
          [Time.zone.parse(record['_time']), record['_value']]
        end
      end

      def bracket(known)
        # Re-partition with <= / > so a reading sitting exactly on the
        # target boundary is treated as the "before" anchor (Flux's
        # range(stop:) is exclusive, so such a point arrives via the
        # "after" stream).
        before = known.select { |t, _| t <= target_time }.max_by(&:first)
        after = known.select { |t, _| t > target_time }.min_by(&:first)
        [before, after]
      end

      def interpolate(before, after)
        # No earlier anchor: treat the first known value as the start
        # anchor. For a monotonic sensor (e.g. an odometer) the value
        # before the first reading cannot have been higher, so using it
        # as a stand-in makes the very first day's diff computable
        # instead of silently dropping it from the telescoping sum.
        return after&.last if before.nil?

        before_time, before_value = before
        return before_value if before_time == target_time
        # No later point yet. Fall back to the last known value; for a
        # monotonic sensor this only underestimates, never overshoots.
        return before_value if after.nil?

        after_time, after_value = after
        span = after_time - before_time
        return before_value if span.zero?

        fraction = (target_time - before_time).fdiv(span)
        before_value + ((after_value - before_value) * fraction)
      end
    end
  end
end
