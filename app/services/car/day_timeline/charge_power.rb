# The power of a charge at the wallbox over its time, for its bar on the
# timeline of a day (see Car::DayTimeline): the 5-minute means of the
# wallbox, split into PV and grid by the power splitter.
#
# The power splitter writes its split some minutes after the power, so the
# running charge ends in buckets without a split. Their power stays unsplit,
# and so does all power of a session without the power splitter. A bucket
# without power in the span is 0 W, like in a pause of the charge.
class Car::DayTimeline::ChargePower
  # The mean power of a bucket in W, at the middle of its 5 minutes, and at
  # the start and the end of the charge
  Point = Data.define(:time, :pv, :grid, :unsplit) do
    def total = pv + grid + unsplit
  end
  public_constant :Point

  # The length of a bucket in seconds
  STEP = Sensor::Query::Helpers::Influx::DailyCurves::BUCKET.to_i
  private_constant :STEP

  # `power` and `grid` are the [[Time, W], ...] of the wallbox and of its
  # grid share, each bucket at its end. `grid` is nil without a split.
  def initialize(from:, to:, power:, grid: nil)
    @from = from
    @to = to
    @power = by_end(power)
    @grid = grid && by_end(grid)
  end

  # [Point, ...] from the start to the end of the charge, empty without power
  def call
    points = ends.map { point(it) }
    return [] if points.none? { it.total.positive? }

    [points.first.with(time: @from), *points, points.last.with(time: @to)]
  end

  private

  # The ends of the buckets that the charge touches, in seconds
  def ends
    first = ((@from.to_i / STEP) + 1) * STEP
    (first...(@to.to_i + STEP)).step(STEP)
  end

  # A bucket of the grid can hold more than the power, because the power
  # splitter divides its own cycles
  def point(stop)
    power = @power.fetch(stop, 0.0)
    time = Time.zone.at(stop - (STEP / 2.0)).clamp(@from, @to)
    grid = @grid&.[](stop)
    return Point.new(time:, pv: 0.0, grid: 0.0, unsplit: power) unless grid

    grid = grid.clamp(0.0, power)
    Point.new(time:, pv: power - grid, grid:, unsplit: 0.0)
  end

  # The last bucket of a day ends a second before midnight (see
  # Sensor::Query::Helpers::Influx::DailyCurves#window_stop), so each time
  # rounds up to the end of its bucket
  def by_end(points) = points.to_h { |time, value| [(time.to_i.to_f / STEP).ceil * STEP, value] }
end
