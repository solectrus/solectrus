module Sensor
  module Query
    # Computes the daily diff for a monotonically increasing sensor (like a
    # car odometer) when the InfluxDB series is sparse, by linearly
    # interpolating the sensor value at each of the day's two boundaries
    # (beginning of the day and beginning of the next day) from the
    # surrounding known points.
    #
    # Properties:
    # - Days with many readings are interpolated exactly at their
    #   boundaries, so dense days keep their precise diff.
    # - Days with no readings still receive a plausible share of the
    #   distance driven between the surrounding known points, distributed
    #   linearly by elapsed time.
    # - Using the next day's beginning (instead of the current day's end)
    #   as the right boundary makes consecutive daily diffs telescope
    #   exactly: SUM(diff) over a range equals odo(range_end_day + 1) -
    #   odo(range_start_day), assuming known points exist on both sides.
    # - Each boundary lookup is a tiny Flux query (two bracketing points)
    #   that is cached forever once its target time is in the past, so a
    #   multi-day summary rebuild reuses every interior boundary.
    # - A multi-day summary rebuild hands in `points` that
    #   Helpers::Influx::DailyDiffs fetched for all its days in one program,
    #   so no boundary lookup runs at all.
    class InterpolatedDiff
      def self.call(sensor_name:, timeframe:, points: nil)
        new(sensor_name:, timeframe:, points:).call
      end

      def initialize(sensor_name:, timeframe:, points: nil)
        @sensor_name = sensor_name
        @timeframe = timeframe
        @points = points
      end

      def call
        start_value = boundary_value(timeframe.beginning)
        end_value = boundary_value(timeframe.beginning_of_next)
        return if start_value.nil? || end_value.nil?

        [end_value - start_value, 0].max
      end

      private

      attr_reader :sensor_name, :timeframe, :points

      def boundary_value(target_time)
        # Clamp the right boundary to "now" so the running day reflects
        # the distance driven up to the current moment instead of
        # extrapolating into the future.
        clamped = [target_time, Time.current].min
        InterpolatedValue.new(sensor_name, clamped, points:).call
      end
    end
  end
end
