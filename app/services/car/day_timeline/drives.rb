# The drives of a car on a day, from the readings of its odometer and of its
# state of charge (see Car::DayTimeline).
#
# The odometer tells that the car drove between two of its readings: from
# the reading before an increase to the reading with it. A car reports at a
# pace of its own, and the collectors differ too. Some write each change
# while the car drives. Others write the odometer of the start until the car
# stops, so the increase comes after the drive. A gap of more than MAX_GAP
# before an increase gives no start: the drive ended by its reading, and
# nothing tells when it began. Its distance at an assumed speed (see
# #assumed_duration) then gives it an assumed start, so a long drive does not
# show as short as a short one. The same holds after a shorter gap in which
# the car stood at a place, like a car that reports only when it parks: the
# drive away from the place took the end of the gap, not all of it.
#
# A car that reports only when it parks or wakes up sends nothing while it
# drives. Its drive then fills the whole time between two readings, which
# can be much longer than the drive. Where no reading lies within a drive
# and its distance needs less time at the assumed speed, the drive starts
# that time before its end. The earlier reading is only the earliest start.
#
# The state of charge falls while the car drives, also where the odometer
# stands still. So where it falls, it tells the start better: the drive
# starts where the state of charge began to fall without a pause. The
# increase of the odometer ends the drive, because a fall can also come
# while the car still drives. Only where the state of charge stood still
# after its last fall, before the increase, the car stood there and the
# odometer caught up late: the drive then ends with that fall. Drives that
# overlap then, like the parts of a long drive that the odometer split, are one
# drive. A fall of one point within a stop, like a visit of a place, is no
# drive. A fall over a long gap tells only that the drive lay in it. Where
# the odometer still stood within the first fall, the drive started after
# that reading. Where the state of charge fell already over a gap in the
# readings before the first fall, the drive started in the gap. A reading of
# the odometer shortly before, without a rise, tells that the car still stood
# then, so the drive starts there. Thus the line of the state
# of charge stays flat while the car stood.
#
# A car that reports its odometer only when it stops tells nothing of a
# drive that still runs. On the running day, a fall of the state of charge
# up to now without an increase of the odometer is therefore a drive up to
# now, without a distance.
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
# ARRIVAL adds a bucket to this lag as a margin. The drive ends there before
# it joins another one, so two drives on both sides of an arrival stay
# apart, also where their times touch.
#
# A car can report the last part of a drive after the arrival, while it
# stands at the place. An increase that ends in the ARRIVAL after the
# start of a stop that still lasts is such a rest, where the stop starts in
# the ARRIVAL after the drive before it: its distance belongs to the drive
# that arrived, and it adds no drive. A car does not drive while
# it charges, so each increase within a charge is the rest of the drive
# that arrived at the charge, also after ARRIVAL.
#
# A drive never overlaps a charge that the car recorded: it ends where the
# charge starts and starts where the charge ends. A drive within a charge
# keeps a mark at the end of the charge. A charge that runs on, like until
# now, has no end yet, so the mark stays at its start.
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
class Car::DayTimeline::Drives # rubocop:disable Metrics/ClassLength
  MAX_GAP = 1.hour
  public_constant :MAX_GAP

  BUCKET = Sensor::Query::Helpers::Influx::DailyCurves::BUCKET
  private_constant :BUCKET

  # A gap of up to this before an increase gives the drive an estimated
  # start (see Car::DayTimeline::Drive#earliest_at). A longer gap says too
  # little, like a night in which the car did not report.
  MAX_ESTIMATED_GAP = 3.hours
  private_constant :MAX_ESTIMATED_GAP

  MAX_PAUSE = 30.minutes
  private_constant :MAX_PAUSE

  # A car can report the state of charge of an arrival some time after the
  # odometer, so a fall up to this after an increase belongs to its drive
  SOC_LAG = BUCKET
  private_constant :SOC_LAG

  # The highest average speed (km/h) that a drive is assumed to take (see
  # #assumed_duration)
  MAX_ASSUMED_SPEED = 80
  private_constant :MAX_ASSUMED_SPEED

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
  # recorded charging sessions. `ends_at` is the end of the data, where a
  # charge runs on. On the `running` day, it is now, where a drive can run
  # on (see #ongoing).
  def initialize(readings, before: nil, soc: [], stops: [], charges: [], ends_at: nil, running: false) # rubocop:disable Metrics/ParameterLists
    @readings = Sensor::MeterReadings.new([*([before] if before), *readings]).call
    @soc = soc.sort_by(&:first)
    @charges = charges.sort_by(&:first)
    @stops = [*stops, *charges]
    @ends_at = ends_at
    @running = running
  end

  def call
    refined = [nil, *increases].each_cons(2).map { |before, increase| cut(refine(increase, after: before&.ended_at)) }
    drives = merge(refined).select { it.distance >= MIN_DISTANCE }.map { stood(clip(it)) }
    ongoing([nil, *drives].each_cons(2).map { |before, drive| drive.unknown_start? ? assume(drive, before) : shorten(drive) })
  end

  private

  # The drive without a start from its distance (see #assumed_duration), not
  # before what tells the car was elsewhere: the drive before it, the reading
  # of the odometer before it, the end of a charge or an arrival
  def assume(drive, before)
    bounds = [
      before&.ended_at,
      stood_at(drive),
      *@charges.map(&:last).select { it <= drive.ended_at },
      arrival_before(drive),
    ]
    drive.with(assumed_at: [drive.ended_at - assumed_duration(drive.distance), *bounds.compact].max)
  end

  # The last reading of the odometer before the drive, where it still stood
  # at the start of the drive. A reading within a drive that joined a later
  # one, like the first report after a gap, tells only that the car drove
  # on.
  def stood_at(drive)
    reached = @readings.filter_map { |time, value| value if time <= drive.ended_at }.max
    return unless reached

    @readings.filter_map { |time, value| time if time < drive.ended_at && value <= reached - drive.distance + TOLERANCE }.max
  end

  # The drive from its distance, where it needs less time than the window of
  # the readings and no reading lies within it. A window that is too long
  # even for a slow drive stays (see Car::DayTimeline::Drive#window?).
  def shorten(drive)
    assumed_at = drive.ended_at - assumed_duration(drive.distance)
    return drive if assumed_at <= drive.start || drive.window? || reported_within?(drive)

    drive.with(assumed_at:)
  end

  def reported_within?(drive) = [*@readings, *@soc].any? { |time, _| time > drive.start && time < drive.ended_at }

  # The time a drive takes at its assumed average speed. A short drive leads
  # through town, a longer one also over country roads and the motorway, so
  # the speed grows with the distance: 20 km/h for 3 km, 29 km/h for 10 km
  # and 48 km/h for 40 km, up to MAX_ASSUMED_SPEED.
  def assumed_duration(distance)
    speed = [(Math.sqrt(distance) * 6) + 10, MAX_ASSUMED_SPEED].min
    (distance.to_f / speed).hours
  end

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
    Car::DayTimeline::Drive.new(started_at: (before if gap <= MAX_GAP), earliest_at: (before if gap > MAX_GAP && gap <= MAX_ESTIMATED_GAP), ended_at: time, distance:)
  end

  # The drive as the state of charge tells it, where it fell before the
  # increase. A fall that ends the drive lies at most MAX_GAP before the
  # reading before the increase, so a fall of an earlier drive stays there.
  # A fall up to SOC_LAG after the end of the increase before, `after`,
  # belongs to that increase: the odometer counted that drive already. A
  # fall after the increase belongs to it only where its step starts before
  # the increase, so the drive does not start after its end.
  def refine(drive, after: nil)
    arrival = arrival_before(drive)
    from = [drive.start - MAX_GAP, arrival].compact.max
    last = falls.rfind { fall_of?(it, drive, from, after) }
    return drive unless last

    # The falls one after the other, back to the reading before the first,
    # and not before the car arrived where the drive starts
    first = last
    first -= 1 while falls.include?(first - 1) && (arrival.nil? || @soc[first - 2].first >= arrival)

    drive.with(started_at: fall_start(first, arrival, odometer_start_within(drive, @soc[first].first)), ended_at: end_at(drive, last))
  end

  # The start of the falls from the index of the first one: the reading
  # before it, or the reading of the odometer before a fall over a gap (see
  # #gap_start), not before the `bounds`
  def fall_start(first, *bounds)
    [[gap_start(first - 1), @soc[first - 1].first].compact.min, *bounds].compact.max
  end

  # The start of a drive in the gap before the reading at the index, where
  # the state of charge fell there by more than NOISE over more than
  # MAX_GAP: the last reading of the odometer in the gap, up to MAX_GAP
  # before the reading. The odometer did not rise there, so the car still
  # stood, like the reading before an increase (see #increase). Without such
  # a reading, the gap says too little, like a car that wakes up only some
  # minutes after it left.
  def gap_start(index)
    return unless index.positive?

    (before_time, before_value), (time, value) = @soc[index - 1], @soc[index]
    return if time - before_time <= MAX_GAP || before_value - value <= NOISE

    @readings.map(&:first).select { it > before_time && it < time && time - it <= MAX_GAP }.max
  end

  # The drive that runs at now on the running day: the state of charge falls
  # up to MAX_PAUSE before now, but the odometer did not rise since, like an
  # odometer that reports only when the car stops. The drive runs until now,
  # without a distance. A fall up to SOC_LAG after the last drive belongs to
  # that drive, and the drive starts after the end of a charge. Where it
  # joins the last drive, like an odometer that reports less often than the
  # state of charge, that drive runs on with the distance so far.
  def ongoing(drives)
    drive = ongoing_after(drives.last&.ended_at) if @running && falling_at_end?
    return drives unless drive
    return [*drives, drive] unless drives.any? && one?(drives.last, drive)

    [*drives[...-1], drives.last.with(ended_at: @ends_at, ongoing: true)]
  end

  # The drive that runs at now after the end of the last drive, or nil
  def ongoing_after(before)
    first = first_of_last_falls(after: before&.+(SOC_LAG))
    return unless first

    charged = @charges.map(&:last).select { it <= @soc[first].first }.max
    Car::DayTimeline::Drive.new(started_at: fall_start(first, before, charged), ended_at: @ends_at, distance: nil, ongoing: true)
  end

  # Whether the last fall lies up to MAX_PAUSE before the end of the data
  def falling_at_end? = @ends_at && falls.any? && @ends_at - @soc[falls.last].first <= MAX_PAUSE

  # The index of the first of the last falls one after the other, all of
  # them after `after`, or nil where the last one lies before
  def first_of_last_falls(after:)
    later = ->(index) { after.nil? || @soc[index].first > after }
    return unless later.call(falls.last)

    first = falls.last
    first -= 1 while falls.include?(first - 1) && later.call(first - 1)
    first
  end

  # Whether the fall at the index belongs to the drive: it lies from `from`
  # up to SOC_LAG after the increase, its step starts before the increase,
  # and it lies more than SOC_LAG after the increase before, `after`
  def fall_of?(index, drive, from, after) = (from..(drive.ended_at + SOC_LAG)).cover?(@soc[index].first) && @soc[index - 1].first <= drive.ended_at && (after.nil? || @soc[index].first > after + SOC_LAG)

  # The last fall where the state of charge stood still after it up to the
  # increase of the odometer: the car stood, and the odometer caught up
  # late. Without such a reading, a fall can come while the car still
  # drives, so the increase ends the drive.
  def end_at(drive, last)
    fall_at, value = @soc[last]
    stood = @soc[(last + 1)..].take_while { |time, _| time <= drive.ended_at }.any? { it.last >= value }
    stood ? fall_at : drive.ended_at
  end

  # The reading of the odometer before the increase, where it lies before
  # the end of the first fall: the car still stood there, so the drive
  # started after it. A reading after the first fall can repeat the value
  # of the start while the car drives, like an odometer that catches up
  # after the drive, so it tells nothing.
  def odometer_start_within(drive, fall_at)
    drive.started_at if drive.started_at && drive.started_at < fall_at
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
  # them apart, also where their times touch. The rest of a drive after its
  # arrival adds its distance alone.
  def merge(drives)
    drives.sort_by(&:ended_at).each_with_object([]) do |drive, merged|
      before = merged.last
      if before && rest?(before, drive) then merged[-1] = before.with(distance: before.distance + drive.distance)
      elsif before && one?(before, drive) then merged[-1] = before.merge(drive)
      else merged << drive
      end
    end
  end

  def one?(before, after) = !arrival?(before, after) && (before.joins?(after) || pause?(before, after))

  def pause?(before, after)
    before.joins?(after, pause: MAX_PAUSE) && @stops.none? { |from, to| from < after.start && to > before.ended_at }
  end

  def arrival?(before, after) = @stops.any? { |from, _| from.between?(before.ended_at, after.start) }

  # Whether the drive after an arrival is the rest of the drive before it:
  # the drive before arrived at the stop, which starts in the ARRIVAL after
  # its end, and the car still stands there. The rest ends in the ARRIVAL
  # after the start of the stop, or later within a charge. A stop that
  # starts later is where the drive after it arrived, like a drive without
  # a start after a long stay.
  def rest?(before, after)
    @stops.any? do |stop|
      from, to = stop
      from.between?(before.ended_at, [after.start, before.ended_at + ARRIVAL].min) && to >= after.ended_at &&
        (after.ended_at <= from + ARRIVAL || @charges.include?(stop))
    end
  end

  # The drive up to the first stop that starts in its last ARRIVAL, and
  # after its start
  def cut(drive)
    from = [drive.started_at, drive.ended_at - ARRIVAL].compact.max
    stop = @stops.map(&:first).select { it > from && it < drive.ended_at }.min
    stop ? drive.with(ended_at: stop) : drive
  end

  # A drive whose estimated start lies within a stop that lasts up to its
  # end, like a stay at a place: the car stood there, so the earliest start
  # tells nothing. The start is then assumed from the distance (see #assume).
  def stood(drive)
    return drive unless drive.estimated_start? && @stops.any? { |from, to| from <= drive.earliest_at && to >= drive.ended_at }

    drive.with(earliest_at: nil)
  end

  # The drive without the time of a charge
  def clip(drive)
    @charges.reduce(drive) do |clipped, (from, to)|
      if to <= clipped.start || from >= clipped.ended_at then clipped
      elsif from > clipped.start then clipped.with(ended_at: from)
      elsif to < clipped.ended_at then clipped.estimated_start? ? clipped.with(earliest_at: to) : clipped.with(started_at: to)
      else clipped.with(started_at: nil, earliest_at: nil, ended_at: mark_at(from, to), within_charge: true)
      end
    end
  end

  # The mark of a drive within a charge: at its end, or at its start where
  # it runs on
  def mark_at(from, to) = @ends_at && to >= @ends_at ? from : to
end
