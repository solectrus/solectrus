# The day of the selected cars, for the overview of a day on the car page
# (see Car::DayTimeline::Component): for each car its drives, its charging
# sessions and the line of its state of charge. The guest has its sessions
# alone, for the guest and for "all".
#
# The sessions come from the table, like the figures above (see
# Car::Report). The drives come from the odometer and the state of charge
# (see Car::DayTimeline::Drives), the line from the readings of the state of
# charge (see Car::DayTimeline::SocLine). The curves of the wallbox are
# those of the daily build (see ChargingSession::Curves), so a pause of a
# charge follows the rules of the detection. The readings of the cars keep
# their own time (see #curves). A car with a location has its visits
# of places (see Place::VisitDetection), which the admin sees as the start
# and the goal of each drive.
class Car::DayTimeline # rubocop:disable Metrics/ClassLength
  # A charging session with the times in which the car charged (see
  # #charge_spans). `power` is the curve of a charge at the wallbox (see
  # Car::DayTimeline::ChargePower), empty for any other charge. `gaps` are
  # the [from, to] within the spans in which the wallbox sent no data (see
  # #gaps_of).
  Charge = Data.define(:session, :spans, :power, :gaps) do
    def initialize(power: [], gaps: [], **) = super

    # From the start to the end of the session, also over a pause
    def span = [spans.first.first, spans.last.last]

    # [[from, to], ...] of the pauses between the spans, in which the car
    # stayed plugged in (see ChargingSession::Detection::Periods)
    def pauses = spans.each_cons(2).map { |(_, stop), (start, _)| [stop, start] }

    # Whether the times are an estimate: an offsite session without an end
    # charged where the signs of its car tell it (see #estimate)
    def estimated? = session.offsite? && session.ended_at.nil?
  end
  public_constant :Charge

  # A lane of a car, or of the guest without a car. `charges` are its
  # Charges, `soc_line` is the line of the state of charge, empty without the
  # sensor. `visits` are the visits of places that the page may show, in the
  # order of time. `plugged` are the [from, to] in which the car was plugged
  # in but did not charge (see Car::DayTimeline::Plugged). `current_place`
  # is the place where the car stands now, like in the live view, or nil
  # (see Car::DayTimeline#current_place). `stays` are the [from, to, Place]
  # in which the car reported its position at a place, also where it stood
  # too short for a visit (see Car::DayTimeline#stays_of).
  Lane = Data.define(:car, :drives, :charges, :soc_line, :visits, :plugged, :current_place, :stays) do
    def initialize(plugged: [], current_place: nil, stays: [], **) = super

    def guest? = car.nil?

    def driving? = !guest? && car.sensor?(:car_odometer)

    def soc? = soc_line.any?

    # The state of charge at the time on the line: the last piece that holds
    # the time, so a step gives its new value
    def soc_at(time)
      segment = soc_line.rfind { time.between?(it.from, it.to) }
      return unless segment
      return segment.to_value if segment.to == segment.from

      segment.from_value + ((segment.to_value - segment.from_value) * (time - segment.from) / (segment.to - segment.from))
    end

    # The place where the drive started: the last visit that began before
    # it. A car reports its place late, so a visit can last until the car
    # arrives at the next place, and only its start is sure. A visit that
    # ended more than VISIT_REACH before the drive belongs to another drive. A
    # drive without a start began before its end. Without such a visit, the
    # last stay at a place before the start tells it.
    def origin(drive) = origin_visit(drive)&.place || origin_stay(drive)

    # The place where the drive ended: the visit after the one where it
    # started that starts closest to its end, VISIT_REACH away at most. A visit
    # that lasts past the end by more than the late report of an arrival
    # (see Car::Rules::ARRIVAL) saw the car back after the
    # drive: a round trip, whose stop was too short for a visit. Without such
    # a visit, the first stay at a place from the end tells it. The last
    # drive without either ends where the car stands now: a stop counts as a
    # visit only after Car::Rules::MIN_STAY. A drive that runs at now has no
    # goal yet.
    def goal(drive)
      return if drive.ongoing

      known_goal(drive) || (current_place if drive == drives.last)
    end

    # Whether the last drive has no visit or stay at a place at its goal
    def open_goal? = drives.any? && !drives.last.ongoing && known_goal(drives.last).nil?

    private

    def known_goal(drive) = visit_goal(drive) || goal_stay(drive)

    # The odometer and the position of one report can come some seconds
    # apart, so a stay counts up to Car::Rules::REPORT_SPREAD around
    # the start or the end of a drive
    def origin_stay(drive)
      latest = drive.start + Car::Rules::REPORT_SPREAD
      range = around(drive)
      stays.select { |from, _, _| range.cover?(from) && from <= latest }.max_by(&:first)&.last
    end

    def goal_stay(drive)
      earliest = drive.ended_at - Car::Rules::REPORT_SPREAD
      range = around(drive)
      stay = stays.select { |from, _, _| range.cover?(from) && from >= earliest }.min_by(&:first)
      stay.last if stay && stay.first - drive.ended_at <= Car::Rules::VISIT_REACH
    end

    def visit_goal(drive)
      origin = origin_visit(drive)
      return origin.place if origin && origin.ended_at > drive.ended_at + Car::Rules::ARRIVAL

      visit = visits_around(drive).select { origin.nil? || it.started_at > origin.started_at }.min_by { (it.started_at - drive.ended_at).abs }
      visit.place if visit && (visit.started_at - drive.ended_at).abs <= Car::Rules::VISIT_REACH
    end

    def origin_visit(drive)
      start = drive.start
      visits_around(drive)
        .select { it.started_at <= start && it.started_at < drive.ended_at && it.ended_at >= start - Car::Rules::VISIT_REACH }
        .max_by(&:started_at)
    end

    # The visits that began from the start of the drive before up to the
    # start of the drive after. A visit outside belongs to another drive,
    # like where the car stood too short for a visit between two drives.
    def visits_around(drive)
      range = around(drive)
      visits.select { range.cover?(it.started_at) }
    end

    # From the start of the drive before up to the start of the drive after
    def around(drive)
      index = drives.index(drive)
      return (nil..nil) unless index

      (drives[index - 1].start if index.positive?)..drives[index + 1]&.start
    end
  end
  public_constant :Lane

  BUCKET = Sensor::Query::Helpers::Influx::DailyCurves::BUCKET
  private_constant :BUCKET

  POSITION_ROLES = %i[car_latitude car_longitude].freeze
  private_constant :POSITION_ROLES

  # [[from, to], ...] of the spans without the times of the cuts. A cut
  # without a length, like a drive without a start, cuts nothing.
  def self.without(spans, cuts)
    cuts.select { |from, to| to > from }.reduce(spans) do |rest, (cut_from, cut_to)|
      rest.flat_map do |from, to|
        next [[from, to]] if cut_to <= from || cut_from >= to

        [[from, cut_from], [cut_to, to]].select { |start, stop| stop > start }
      end
    end
  end

  # Only the admin sees the places of a car, like on the chart of the
  # distance
  def initialize(timeframe, cars, guest: false, admin: false)
    @timeframe = timeframe
    @cars = cars
    @guest = guest
    @admin = admin
  end

  attr_reader :timeframe

  # Starts the curves of the day in the background, so they load while the
  # page renders the figures above the timeline. Only a wallbox session
  # needs the curves of the wallbox (see #charge_spans). The positions load
  # beside them (see #position_curves).
  def start
    tap do
      curves.start(wallbox: sessions.any?(&:wallbox?))
      position_curves.start(wallbox: false)
    end
  end

  # Whether a time is the end of the data on the running day, so that what
  # ends there still runs, like the time plugged in
  def now?(time) = today? && time >= stops_at

  # A lane for each car, and one for the guest sessions of the day. "all"
  # leaves out the guest on a day without a guest session.
  def lanes
    @lanes ||= [*@cars.map { car_lane(it) }, guest_lane].compact
  end

  private

  delegate :beginning, :today?, to: :timeframe

  # The end of the data: now on the running day, the same now for the whole
  # timeline
  def stops_at = @stops_at ||= [timeframe.beginning_of_next, Time.current].min

  def charges
    @charges ||= sessions.map do |session|
      spans = charge_spans(session)
      Charge.new(session:, spans:, power: power_of(session, spans), gaps: gaps_of(session, spans))
    end
  end

  # The gaps of the wallbox within the spans of a session at the wallbox. The
  # detection counts them to the charge (see
  # ChargingSession::Detection::Periods), but the curve has no power there.
  def gaps_of(session, spans)
    return [] unless session.wallbox?

    spans.flat_map { |from, to| wallbox_gaps.filter_map { |gap_from, gap_to| [[gap_from, from].max, [gap_to, to].min] if gap_from < to && gap_to > from } }
  end

  # [[from, to], ...] of the times of the day in which the collector of the
  # wallbox sent no data, each bucket over the 5 minutes before its end. The
  # bucket before a gap holds the last readings, and the time after them is
  # unknown too. Without power, it has nothing to draw, so the gap starts
  # with it, like a part of the detection.
  def wallbox_gaps
    @wallbox_gaps ||= begin
      powered = wallbox_curve(curves.wallbox).to_set { it.first.to_i }
      wallbox_curve(curves.wallbox_gaps)
        .map { |time, _| [time - BUCKET, time] }
        .chunk_while { |before, after| before.last >= after.first }
        .map { |run| [run.first.first, run.last.last] }
        .map { |from, to| [powered.include?(from.to_i) ? from : from - BUCKET, to] }
    end
  end

  # [[Time, W], ...] of a sensor of the wallbox on the day, from its curves or
  # its gaps. Without the grid share, each bucket stays unsplit (see
  # ChargePower).
  def wallbox_curve(source, name = :wallbox_power) = source.dig(timeframe.date, name) || []

  # The curve of the wallbox over the time of a session at the wallbox,
  # split where the power splitter split its energy
  def power_of(session, spans)
    return [] unless session.wallbox?

    grid = wallbox_curve(curves.wallbox, :wallbox_power_grid) if session.kwh_grid
    ChargePower.new(from: spans.first.first, to: spans.last.last, power: wallbox_curve(curves.wallbox), grid:).call
  end

  # The charging sessions of the day, a running one marked (see
  # ChargingSession::Ongoing). A session belongs to the day of its start, but
  # a session that charged over midnight shows on the next day too.
  def sessions
    @sessions ||=
      ChargingSession
      .of_cars(@cars, guest: @guest)
      .effective
      .where(started_at: ...timeframe.beginning_of_next)
      .where('charging_sessions.started_at >= :beginning OR charging_sessions.ended_at > :beginning', beginning:)
      .order(:started_at)
      .to_a
      .tap { ChargingSession.mark_ongoing(it) if today? }
  end

  # The times in which a session charged. A session at the wallbox can pause
  # while the car stays plugged in, like until the cheap tariff of the night.
  # Its parts with power follow the rules of the detection (see
  # ChargingSession::Detection::Periods), up to the end of the session: the
  # curves can hold a part that the build did not store yet. The session
  # stores the readings at its edges, which lie within the first and the
  # last bucket (see ChargingSession::Detection::Edges), so its pauses alone
  # stay on the edges of the buckets. Any other session charged over its
  # whole span. The spans end at the edges of the day.
  def charge_spans(session)
    from, to = span_of(session)
    parts = (wallbox_parts[bucket_start(session.started_at)]&.select { |start, _| start < to } if session.wallbox?).presence || [[from, to]]
    [from, *parts.flatten[1...-1], to].each_slice(2).map { |start, stop| [[start, beginning].max, [stop, timeframe.beginning_of_next].min] }
  end

  # The start of the bucket that holds the time, in seconds
  def bucket_start(time) = time.to_i - (time.to_i % BUCKET.to_i)

  # The start and the end of a session. A running session charges until now.
  # An offsite session without an end can have charged over the rest of its
  # day (see #estimate).
  def span_of(session)
    return [session.started_at, session.ended_at] if session.ended_at && !session.ongoing?

    [session.started_at, stops_at]
  end

  # { start => [[from, to], ...] } of the periods of the wallbox on the day
  def wallbox_parts
    @wallbox_parts ||= ChargingSession::Detection::Periods.of(curves, timeframe.date).call.to_h { [it.from.to_i, it.parts] }
  end

  # Driving and charging never overlap. A drive gives way to a charge that
  # the car recorded (see Car::DayTimeline::Drives), and an estimated charge
  # gives way to a drive (see #estimate).
  def car_lane(car)
    soc = soc_readings(car)
    plug = plug_readings(car)
    recorded, estimated = charges_of(car).partition { !it.estimated? }
    stays = stays_of(car)
    drives = drives_of(car, soc, recorded, stays)
    charges = [*recorded, *estimated.map { estimate(it, soc:, plug:, drives:, recorded:) }].sort_by { it.span.first }

    lane = Lane.new(car:, drives:, charges:, soc_line: soc_line(soc, drives, charges), visits: (@admin ? visits_of(car) : []), plugged: plugged_of(plug, charges, drives), stays: (@admin ? named(stays) : []))
    @admin && today? && lane.open_goal? ? lane.with(current_place: current_place(car)) : lane
  end

  # The place at the latest position of the car, like in the live view (see
  # Car::Live), or nil on the road. The build writes a visit only after
  # Car::Rules::MIN_STAY, so on the running day the last drive can end at a
  # place that has no visit yet. The build also makes the place itself, so
  # a new position takes the town that the live view found there, as a place
  # that is not saved.
  def current_place(car)
    return unless Sensor::Cars.located?(car.id)

    location = Car::Live.new([car]).states.sole.location
    return unless location

    Place.near(*location) || town_at(*location)
  end

  # An unsaved place with the town at a location, from the cache of the live
  # view (see Place.known_name_at), or nil before its first answer
  def town_at(latitude, longitude)
    name = Place.known_name_at(latitude, longitude)
    Place.new(latitude:, longitude:, name:) if name
  end

  # The charge of an offsite session without an end where the signs of its
  # car tell it, from the readings of the rest of the lane (see
  # Car::DayTimeline::OffsiteEstimate). It charged before the next session of
  # the car. Without a time free of drives and other charges, it keeps the
  # rest of its day.
  def estimate(charge, soc:, plug:, drives:, recorded:)
    from, to = charge.span
    to = [to, *charges_of(charge.session.car).map { it.session.started_at }.select { it > from }].min
    span = OffsiteEstimate.new(from:, to:, soc:, plug:, drives: drives.map(&:span), charges: recorded.map(&:span)).call
    span ? charge.with(spans: [span]) : charge
  end

  def guest_lane
    return unless @guest

    guest_charges = charges.select { it.session.car_id.nil? }
    Lane.new(car: nil, drives: [], charges: guest_charges, soc_line: [], visits: []) if guest_charges.any? || @cars.empty?
  end

  def charges_of(car) = charges.select { it.session.car_id == car.id }

  # The car stood from the start to the end of each recorded charge, also in
  # a pause of the charge, and while it visited a place. So a pause with such
  # a stop splits two drives, and a drive never overlaps a recorded charge
  # (see Car::DayTimeline::Drives). The visits tell this to each viewer,
  # without their places, and so do the stays, where the car stood too short
  # for a visit.
  def drives_of(car, soc, charges, stays)
    return [] unless car.sensor?(:car_odometer)

    before, readings = car_curve(car, :car_odometer).partition { |time, _| time < beginning }
    stops = [*visits_of(car).map { [it.started_at, it.ended_at] }, *stays.map { |from, to, _| [from, to] }]
    Drives.new(readings, before: before.last, soc:, stops:, charges: charges.map(&:span), ends_at: stops_at, running: today?).call
  end

  # The line from the value at the start of the day to now or the end of the
  # day. A rise follows the times where the car charged.
  def soc_line(soc, drives, charges)
    return [] if soc.empty?

    SocLine.new(
      soc,
      ends_at: stops_at,
      drives: drives.map { [*it.span, it.distance] },
      charges: charges.flat_map(&:spans),
    ).call
  end

  # The readings of the state of charge, the last one before the day at the
  # start of the day. A value of 0 or above 100 is no reading (see
  # ChargingSession::Curves.soc_reading?). Empty without the sensor.
  def soc_readings(car) = day_points(car_curve(car, :car_battery_soc))

  # The readings of the plug, the last one before the day at the start of the
  # day. Empty without the sensor.
  def plug_readings(car) = day_points(car_curve(car, :car_connected))

  # The times in which the car was plugged in but did not charge, from the
  # readings of its plug. A drive within a charge ends no time plugged in,
  # because the car stayed plugged in for the charge.
  def plugged_of(plug, charges, drives)
    Plugged.new(plug, ends_at: stops_at, charges: charges.map(&:span), drives: drives.reject(&:within_charge).map(&:span)).call
  end

  # The readings of the day, the last one before the day at the start of the
  # day
  def day_points(readings)
    before, points = readings.partition { |time, _| time < beginning }
    [*([[beginning, before.last.last]] if before.any?), *points]
  end

  def visits_of(car) = visits.select { it.car_id == car.id }

  # [[from, to, Place], ...] of the stays of a car at a place, from its first
  # to its last reading there. A car that reports rarely can stand at a place
  # for less than a visit needs (see Place::VisitDetection), but it was there,
  # so the stay ends the drive there and starts the next one. A car that
  # reports often passes places on the road, so a stay needs the time for a
  # stop (see #long_runs). The readings within Car::Rules::PLACE_RADIUS of
  # each other are one stay, so only a stay asks for its place. The stay
  # takes the place of its first reading within the radius of one, because
  # its first reading can come at the arrival, still outside the radius.
  def stays_of(car)
    return [] unless stays?(car)

    long_runs(positions(car), car_curve(car, :car_odometer)).filter_map do |run|
      place = run.lazy.filter_map { |_, latitude, longitude| Place.near(latitude, longitude, places) }.first
      [run.first.first, run.last.first, place] if place
    end
  end

  # The runs of the positions within Car::Rules::PLACE_RADIUS of each other
  # in which the car can have stood for Car::Rules::MIN_STOP, up to the next
  # reading elsewhere (see #standing_time)
  def long_runs(positions, odometer)
    runs = positions.chunk_while { |(_, *before), (_, *after)| Geo.distance(*before, *after) <= Car::Rules::PLACE_RADIUS }.to_a
    left = [*runs.drop(1).map { it.first.first }, stops_at]
    runs.zip(left).filter_map { |run, left_at| run if standing_time(run.first.first, left_at, odometer) >= Car::Rules::MIN_STOP }
  end

  # The longest time in which the car can have stood between two times: the
  # rise of the odometer between them takes its time at
  # Car::Rules::MAX_ASSUMED_SPEED. So a car that reports every 15 minutes
  # and passes a place has no time left for a stop there. The odometer of a
  # report can come some seconds after its position. Without a reading of
  # the odometer, the car stood the whole time.
  def standing_time(from, to, odometer)
    before, after = [from, to].map { odometer_at(odometer, it + Car::Rules::REPORT_SPREAD) }
    rise = before && after ? [after - before, 0].max : 0
    (to - from) - (rise.fdiv(Car::Rules::MAX_ASSUMED_SPEED) * 1.hour)
  end

  # Whether the positions of a car give stays. A stay only ends a drive,
  # and the drives come from the odometer (see #drives_of).
  def stays?(car) = car.located? && car.sensor?(:car_odometer)

  # The odometer at a time, from the last reading up to it, or nil
  def odometer_at(odometer, time)
    index = odometer.bsearch_index { |at, _| at > time } || odometer.size
    odometer[index - 1].last if index.positive?
  end

  # [[Time, latitude, longitude], ...] of the readings of the position of a
  # car, each latitude with its longitude within Car::Rules::REPORT_SPREAD
  def positions(car)
    longitudes = car_curve(car, :car_longitude)
    car_curve(car, :car_latitude).filter_map do |time, latitude|
      index = longitudes.bsearch_index { |at, _| at >= time - Car::Rules::REPORT_SPREAD }
      at, longitude = longitudes[index] if index
      [time, latitude, longitude] if at && at <= time + Car::Rules::REPORT_SPREAD
    end
  end

  # The places, read once for all cars, without their stored address (see
  # Place#geocoding): a stay needs only where a place is
  def places = @places ||= Place.select(:id, :latitude, :longitude).to_a

  # The stays with their places, for the names that the admin sees
  def named(stays)
    places = Place.where(id: stays.map { it.last.id }).index_by(&:id)
    stays.map { |from, to, place| [from, to, places[place.id]] }
  end

  # The visits of the day
  def visits
    @visits ||=
      PlaceVisit
      .where(car_id: @cars.map(&:id), date: timeframe.date)
      .order(:started_at)
      .preload(:place)
      .to_a
  end

  # [[Time, value], ...] of a role of a car, from its reading before the day,
  # without the readings that repeat a stale state (see
  # Car::DayTimeline::StaleReadings). The state of charge keeps only its
  # readings (see ChargingSession::Curves.soc_reading?).
  def car_curve(car, role)
    stale = stale_of(car)
    readings_of(car, role).reject { |time, _| stale.any? { |from, to| time > from && time < to } }
  end

  def readings_of(car, role)
    return [] unless car.sensor?(role)

    readings = curve(car.sensor_name(role), POSITION_ROLES.include?(role) ? position_curves : curves)
    role == :car_battery_soc ? readings.select { ChargingSession::Curves.soc_reading?(it.last) } : readings
  end

  def stale_of(car)
    @stale ||= {}
    @stale[car.id] ||= StaleReadings.new(odometer: readings_of(car, :car_odometer), soc: readings_of(car, :car_battery_soc), plug: readings_of(car, :car_connected)).call
  end

  # [[Time, value], ...] of a sensor of a car up to the end of the data, from
  # its reading before the day, in the time zone of the page. A collector
  # whose clock runs ahead can write a reading after now, which shows at now.
  def curve(name, source)
    (source.cars.dig(timeframe.date, name) || []).map { |time, value| [[time, stops_at].min.in_time_zone, value] }
  end

  # The curves of the daily build on the day. Each one loads when the
  # timeline first reads it, or all at once after #start. The places come
  # from the visits, and the positions give the stays too short for a visit
  # (see #position_curves, and #current_place for the latest one). A curve of
  # a car starts with its last reading before the day, so the timeline needs
  # no margin around the day. A session that the power splitter split adds
  # the grid share of the wallbox (see #power_of). The readings of a car keep
  # their own time, because a bucket carries the end of its 5 minutes: a car
  # that reports when it leaves would start its drive up to 5 minutes late.
  def curves
    @curves ||= ChargingSession::Curves.new(
      [timeframe.date],
      cars: @cars,
      roles: %i[car_battery_soc car_odometer car_connected],
      margin: 0,
      split: sessions.any?(&:kwh_grid),
      reading_time: true,
    )
  end

  # The positions of the cars with stays on the day (see #stays_of), in
  # a program of their own: each sensor adds a fixed time to a program, so
  # the positions load beside the other curves after #start and add no time
  # to the page
  def position_curves
    @position_curves ||= ChargingSession::Curves.new([timeframe.date], cars: @cars.select { stays?(it) }, roles: POSITION_ROLES, margin: 0, reading_time: true)
  end
end
