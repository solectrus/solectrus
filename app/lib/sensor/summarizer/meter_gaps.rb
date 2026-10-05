module Sensor
  class Summarizer
    # The days whose increase a meter lost to a gap in its readings, for
    # example a car odometer while the car is offline (see
    # Influx::DailyDiffs).
    #
    # Without a later reading, a day ends at the last reading, so a day built
    # during a gap gets no share of the distance that the next reading shows.
    # The days after the gap get only their own share, and the sum of the
    # days stays too small. Once the next reading is there, the build of a
    # later day finds the gap, and the days of the gap that were built before
    # this reading are built again.
    #
    # A gap shows at the first midnight of each run of rebuilt days: the last
    # reading before it and the first reading after it. Each day from the
    # last reading to this midnight interpolates between the two. A gap
    # without a change of the meter changes no day, so a car that stood still
    # gives no build.
    #
    # A run whose day before was built in the same build of the summaries
    # has no stale day: this day saw each reading up to now, and the check of
    # an earlier run covered the days before it.
    #
    # The two readings are among the points of Influx::DailyDiffs for the same
    # days: its last reading before each run and the first readings after it.
    # The build reads these points for the daily increase anyway, so a gap
    # costs no query of its own. A wrong reading, like a 0 of an offline car,
    # is left out there, so it makes no gap.
    class MeterGaps
      # The days that interpolate between two readings, and the time of the
      # second reading
      Gap = ::Data.define(:dates, :closed_at)
      public_constant :Gap

      # `dates` are the days that the chunk builds again, `diffs` the
      # Influx::DailyDiffs of these days, and `built` the days that the same
      # build of the summaries built before
      def initialize(dates, diffs, built: Set.new)
        program = Sensor::Query::Helpers::Influx::FluxProgram
        @starts = program.runs(dates).map(&:first)
        @starts.select! { it.beginning_of_day > program.installation_time && built.exclude?(it.prev_day) }
        @diffs = diffs
        @future = Concurrent::Future.execute { gaps } if diffs.sensor_names.any? && @starts.any?
      end

      # Waits for the points of the diffs, outside the transaction
      def result
        @result ||= @future ? @future.value! : []
      end

      # Removes the summaries of the stale days, so the next build makes them
      # again, and returns these days. The values of a summary go with it
      # (foreign key cascade).
      def remove!(built)
        dates = stale_dates(built)
        Summary.where(date: dates).delete_all if dates.any?
        dates
      end

      # The days of the gaps that were built before the reading after the gap,
      # without the given days, which the chunk builds now
      def stale_dates(built)
        return [] if result.empty?

        result
          .map { |gap| Summary.where(date: gap.dates, updated_at: ...gap.closed_at) }
          .reduce(:or)
          .where.not(date: built)
          .pluck(:date)
      end

      private

      attr_reader :starts, :diffs

      # A reading in the future cannot close a gap yet, because a day built now
      # would not see it either
      def gaps
        now = Time.current
        starts.flat_map { |date| diffs.points.values.filter_map { gap(date, it, now) } }
      end

      # The gap of a meter before the run that starts on the date, or nil
      def gap(date, readings, now)
        midnight = date.beginning_of_day
        before = readings.rfind { |time, _| time < midnight }
        after = readings.find { |time, _| time.between?(midnight, now) }
        return unless before && after && before.last != after.last

        Gap.new(dates: before.first.in_time_zone.to_date..(date - 1), closed_at: after.first)
      end
    end
  end
end
