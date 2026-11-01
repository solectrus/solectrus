# A drive of a car on a day, as Car::DayTimeline::Drives finds it.
#
# `started_at` is nil when nothing tells the start. `earliest_at` is then the
# earliest time at which it can have started, the reading before a gap in the
# readings, or nil. `assumed_at` is the start from the distance, where nothing
# tells it or where the readings leave a longer window. `within_charge` marks
# a drive that lies within a recorded charge, at its end, or at its start
# where it runs on.
Car::DayTimeline::Drive = Data.define(:started_at, :ended_at, :distance, :earliest_at, :assumed_at, :within_charge)

class Car::DayTimeline::Drive
  # The average speeds (km/h) of a drive that fit its time. A drive below
  # MIN_SPEED for longer than MIN_WINDOW is a short drive within a window of
  # the readings. Above MAX_SPEED, the time is too short.
  MIN_SPEED = 5
  MIN_WINDOW = 20.minutes
  MAX_SPEED = 150
  private_constant :MIN_SPEED, :MIN_WINDOW, :MAX_SPEED

  BUCKET = Sensor::Query::Helpers::Influx::DailyCurves::BUCKET
  private_constant :BUCKET

  def initialize(earliest_at: nil, assumed_at: nil, within_charge: false, **) = super

  # The start: the assumed one, the one of the readings, the earliest one
  # where it is an estimate, or the end
  def start = assumed_at || started_at || earliest_at || ended_at

  def span = [start, ended_at]

  # Whether the start is the earliest time at which the drive can have
  # started
  def estimated_start? = started_at.nil? && !earliest_at.nil? && assumed_at.nil?

  # Whether nothing tells the start, so the start is assumed
  def unknown_start? = started_at.nil? && earliest_at.nil? && !within_charge

  # Whether the start comes from the distance, not from a reading
  def assumed_start? = !assumed_at.nil?

  def duration = ended_at - start

  # Whether the drive takes longer than its distance needs. Its time is then
  # the window between two readings, in which a short drive took place.
  def window? = duration > MIN_WINDOW && distance / (duration / 1.hour) < MIN_SPEED

  # Whether the drive is faster than a car drives, so its start lies too
  # late. The check adds a bucket as a margin, so a drive that is some
  # minutes short does not count as too fast.
  def too_fast? = duration.positive? && distance / ((duration + BUCKET) / 1.hour) > MAX_SPEED

  # Whether the other drive, which ends later, starts within `pause` after
  # this one
  def joins?(other, pause: 0) = other.start <= ended_at + pause

  # One drive of both. The drive that starts first gives the start, also
  # where it is an estimate, so the estimate stays one.
  def merge(other)
    first = [self, other].min_by(&:start)
    with(
      started_at: first.started_at,
      earliest_at: first.earliest_at,
      ended_at: [ended_at, other.ended_at].max,
      distance: distance + other.distance,
    )
  end
end
