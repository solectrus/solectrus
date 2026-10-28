# The drives of a car on a day, from the readings of its odometer and of its
# state of charge (see Car::DayTimeline).
#
# The odometer tells that the car drove between two of its readings: from
# the reading before an increase to the reading with it. A car reports at a
# pace of its own, and the collectors differ too. Some write each change
# while the car drives. Others write the odometer of the start until the car
# stops, so the increase comes after the drive. A gap of more than MAX_GAP
# before an increase gives no start: the drive ended by its reading, and
# nothing tells when it began.
#
# The state of charge falls while the car drives, also where the odometer
# stands still. So where it falls, it tells the drive better: the drive ends
# with the last fall before the increase of the odometer, and it starts where
# the state of charge began to fall without a pause. Drives that overlap
# then, like the parts of a long drive that the odometer split, are one
# drive. A fall of one point within a stop, like a visit of a place, is no
# drive.
#
# The state of charge reports at a pace of its own too, so it can stand
# still for a reading while the car drives. A pause of up to MAX_PAUSE
# between two drives therefore joins them, unless the car stood in it: a
# charge or a visit of a place splits them, while a short pause says too
# little to split a drive in the overview of a day.
#
# A car that stands does not drive, so a drive ends where a charge or a visit
# starts in its last ARRIVAL. A car reports late, like for the detection
# of the wallbox sessions (see
# ChargingSession::Detection::CarAssignment::REPORT_LAG), so the reading with
# the increase can come some minutes after the car arrived and plugged in.
# A reading carries the end of its bucket, which can lie a bucket later.
# The drive ends there before it joins another one, so two drives on both
# sides of an arrival stay apart, also where their times touch.
#
# A drive never overlaps a charge that the car recorded: it ends where the
# charge starts and starts where the charge ends. A drive within a charge
# keeps a mark at the end of the charge.
#
# A drive shorter than MIN_DISTANCE, like moving the car in front of the
# house, is no drive: its distance shows as 0 km. It counts after the drives
# are joined, so the short parts of a slow drive stay in it.
#
# A wrong reading of the odometer, like a 0 of an offline car, is left out
# (see Sensor::MeterReadings). A reading that steps back within the rounding
# of the meter adds no drive, because a drive counts from the highest
# reading before it. A larger step back that stays is a new source of the
# meter, so the drives count from there.
class Car::DayTimeline::Drives
  # `started_at` is nil when nothing tells the start. `earliest_at` is then
  # the earliest time at which it can have started, the reading before a gap
  # in the readings (see #increases), or nil. `within_charge` marks a drive
  # that lies within a recorded charge, at its end (see #clip).
  Drive = Data.define(:started_at, :ended_at, :distance, :earliest_at, :within_charge) do
    def initialize(earliest_at: nil, within_charge: false, **) = super

    # The start, the earliest one where it is an estimate, or the end where
    # nothing tells the start
    def start = started_at || earliest_at || ended_at

    def span = [start, ended_at]

    # Whether the start is the earliest time at which the drive can have
    # started
    def estimated_start? = started_at.nil? && !earliest_at.nil?

    # Whether nothing tells the start, so the drive is a mark at its end
    def unknown_start? = started_at.nil? && earliest_at.nil? && !within_charge

    def duration = ended_at - start

    # Whether the drive takes longer than its distance needs. Its time is
    # then the window between two readings, in which a short drive took
    # place.
    def window? = duration > MIN_WINDOW && distance / (duration / 1.hour) < MIN_SPEED

    # Whether the drive is faster than a car drives, so its start lies too
    # late. The readings come in buckets, so the time can be a bucket short.
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
  public_constant :Drive

  MAX_GAP = 1.hour
  public_constant :MAX_GAP

  # The average speeds (km/h) of a drive that fit its time. A drive below
  # MIN_SPEED for longer than MIN_WINDOW is a short drive within a window of
  # the readings. Above MAX_SPEED, the time is too short.
  MIN_SPEED = 5
  MIN_WINDOW = 20.minutes
  MAX_SPEED = 150
  private_constant :MIN_SPEED, :MIN_WINDOW, :MAX_SPEED

  BUCKET = Sensor::Query::Helpers::Influx::DailyCurves::BUCKET
  private_constant :BUCKET

  # A gap of up to this before an increase gives the drive an estimated
  # start (see Drive#earliest_at). A longer gap says too little, like a
  # night in which the car did not report.
  MAX_ESTIMATED_GAP = 3.hours
  private_constant :MAX_ESTIMATED_GAP

  MAX_PAUSE = 30.minutes
  private_constant :MAX_PAUSE

  # The distance (km) below which a drive rounds to 0 km
  MIN_DISTANCE = 0.5
  private_constant :MIN_DISTANCE

  # A change of one percentage point of the state of charge is the noise of
  # the reading, like a cold battery
  NOISE = 1
  public_constant :NOISE

  ARRIVAL = ChargingSession::Detection::CarAssignment::REPORT_LAG + Sensor::Query::Helpers::Influx::DailyCurves::BUCKET
  public_constant :ARRIVAL

  # Rounding of the source (see Sensor::MeterReadings)
  TOLERANCE = Sensor::MeterReadings::TOLERANCE
  private_constant :TOLERANCE

  # `readings` are the [[Time, value], ...] of the odometer on the day.
  # `before` is the last reading before the day, or nil before the first
  # reading of the meter. `soc` are the readings of the state of charge on
  # the day, empty without the sensor. `stops` are the [from, to] where the
  # car stood, like its visits of places, and `charges` those of its
  # recorded charging sessions.
  def initialize(readings, before: nil, soc: [], stops: [], charges: [])
    @readings = Sensor::MeterReadings.new([*([before] if before), *readings]).call
    @soc = soc.sort_by(&:first)
    @charges = charges.sort_by(&:first)
    @stops = [*stops, *charges]
  end

  def call
    merge(increases.map { cut(refine(it)) }).select { it.distance >= MIN_DISTANCE }.map { clip(it) }
  end

  private

  # A drive for each increase of the odometer, from the reading before it.
  # After a longer gap, the reading before it is only the earliest start.
  def increases
    highest = nil
    previous_time = nil

    @readings.each_with_object([]) do |(time, value), drives|
      if highest && value > highest
        drives << increase(previous_time, time, value - highest)
        highest = value
      end

      highest = value if highest.nil? || value < highest - TOLERANCE
      previous_time = time
    end
  end

  def increase(before, time, distance)
    gap = time - before
    Drive.new(started_at: (before if gap <= MAX_GAP), earliest_at: (before if gap > MAX_GAP && gap <= MAX_ESTIMATED_GAP), ended_at: time, distance:)
  end

  # The drive as the state of charge tells it, where it fell before the
  # increase. A fall that ends the drive lies at most MAX_GAP before the
  # reading before the increase, so a fall of an earlier drive stays there.
  def refine(drive)
    arrival = arrival_before(drive)
    from = [drive.start - MAX_GAP, arrival].compact.max
    last = falls.rfind { (from..drive.ended_at).cover?(@soc[it].first) }
    return drive unless last

    # The falls one after the other, back to the reading before the first,
    # and not before the car arrived where the drive starts
    first = last
    first -= 1 while falls.include?(first - 1) && (arrival.nil? || @soc[first - 2].first >= arrival)

    drive.with(started_at: [@soc[first - 1].first, arrival].compact.max, ended_at: @soc[last].first)
  end

  # The indexes of the readings of the state of charge below the reading
  # before them, with a gap of MAX_GAP at most. A fall of NOISE over more
  # than MAX_PAUSE is no drive, like a cold battery while the car stands: a
  # short drive falls by a point within some minutes.
  def falls
    @falls ||= (1...@soc.size).select do |index|
      (before_time, before_value), (time, value) = @soc[index - 1], @soc[index]
      gap = time - before_time
      value < before_value && gap <= MAX_GAP && !(before_value - value <= NOISE && gap > MAX_PAUSE)
    end
  end

  # The last start of a stop before the drive, where the car arrived before
  # it drove on. A stop that starts in the last ARRIVAL of the drive is
  # where the drive arrives (see #cut).
  def arrival_before(drive) = @stops.map(&:first).select { it < drive.ended_at - ARRIVAL }.max

  # Drives in the order of their end, one where they overlap or where a short
  # pause without a stop lies between them. An arrival between them keeps
  # them apart, also where their times touch.
  def merge(drives)
    drives.sort_by(&:ended_at).each_with_object([]) do |drive, merged|
      if merged.last && !arrival?(merged.last, drive) && (merged.last.joins?(drive) || pause?(merged.last, drive))
        merged[-1] = merged.last.merge(drive)
      else
        merged << drive
      end
    end
  end

  def pause?(before, after)
    before.joins?(after, pause: MAX_PAUSE) && @stops.none? { |from, to| from < after.start && to > before.ended_at }
  end

  def arrival?(before, after) = @stops.any? { |from, _| from.between?(before.ended_at, after.start) }

  # The drive up to the first stop that starts in its last ARRIVAL, and
  # after its start
  def cut(drive)
    from = [drive.started_at, drive.ended_at - ARRIVAL].compact.max
    stop = @stops.map(&:first).select { it > from && it < drive.ended_at }.min
    stop ? drive.with(ended_at: stop) : drive
  end

  # The drive without the time of a charge
  def clip(drive)
    @charges.reduce(drive) do |clipped, (from, to)|
      if to <= clipped.start || from >= clipped.ended_at then clipped
      elsif from > clipped.start then clipped.with(ended_at: from)
      elsif to < clipped.ended_at then clipped.estimated_start? ? clipped.with(earliest_at: to) : clipped.with(started_at: to)
      else clipped.with(started_at: nil, earliest_at: nil, ended_at: to, within_charge: true)
      end
    end
  end
end
