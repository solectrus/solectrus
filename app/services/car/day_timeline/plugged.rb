# The times in which a car was plugged in but did not charge, for the
# timeline of a day (see Car::DayTimeline): the runs of the readings of its
# plug, without the times of its charging sessions, which the bars of the
# charges show, and of its drives. A reading is a state, so it holds until
# the next one, and the last one until the end of the data. A car reports
# that it was unplugged late, like after the drive, so a drive ends the time
# plugged in.
class Car::DayTimeline::Plugged
  # A rest below this is the offset of a reading to its session, not a time
  # of its own
  MIN_TIME = Sensor::Query::Helpers::Influx::DailyCurves::BUCKET
  private_constant :MIN_TIME

  # `points` are the [[Time, value], ...] of the plug, the state at the start
  # of the day first. A positive value is plugged in. `charges` and `drives`
  # are the [from, to] of the charging sessions and of the drives of the car.
  def initialize(points, ends_at:, charges: [], drives: [])
    @points = points.sort_by(&:first)
    @ends_at = ends_at
    @drives = drives
    @cuts = [*charges, *drives]
  end

  # [[from, to], ...]
  def call
    Car::DayTimeline.without(runs.map { |from, to| [from, unplugged_at(from, to)] }, @cuts).select { |from, to| to - from >= MIN_TIME }
  end

  private

  # The end of a run: the start of the first drive in it
  def unplugged_at(from, to) = [*@drives.map(&:first).select { it > from && it < to }, to].min

  # The times of the readings that are plugged in, joined where one follows
  # the other
  def runs
    @points
      .each_with_index
      .filter_map { |(time, value), index| [time, @points[index + 1]&.first || @ends_at] if value.positive? }
      .slice_when { |before, after| before.last != after.first }
      .map { [it.first.first, it.last.last] }
  end
end
