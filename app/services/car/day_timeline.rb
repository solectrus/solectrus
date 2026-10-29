# The day of the selected cars, for the overview of a day on the car page
# (see Car::DayTimeline::Component): for each car its drives, its charging
# sessions and the line of its state of charge. The guest has its sessions
# alone, for the guest and for "all".
#
# The sessions come from the table, like the figures above (see
# Car::Report). The drives come from the odometer and the state of charge
# (see Car::DayTimeline::Drives), the line from the readings of the state of
# charge (see Car::DayTimeline::SocLine). The curves of the day are those of
# the daily build (see ChargingSession::Curves), so a pause of a charge
# follows the rules of the detection. A car with a location has its visits
# of places (see Place::VisitDetection), which the admin sees as the start
# and the goal of each drive.
class Car::DayTimeline # rubocop:disable Metrics/ClassLength
  # A charging session with the times in which the car charged (see
  # #charge_spans). `power` is the curve of a charge at the wallbox (see
  # Car::DayTimeline::ChargePower), empty for any other charge.
  Charge = Data.define(:session, :spans, :power) do
    def initialize(power: [], **) = super

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
  # in but did not charge (see Car::DayTimeline::Plugged).
  Lane = Data.define(:car, :drives, :charges, :soc_line, :visits, :plugged) do
    def initialize(plugged: [], **) = super

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
    # ended more than an hour before the drive belongs to another drive. A
    # drive without a start began before its end.
    def origin(drive) = origin_visit(drive)&.place

    # The place where the drive ended: the visit after the one where it
    # started that starts closest to its end, an hour away at most. A visit
    # that lasts past the end by more than the late report of an arrival
    # (see Car::DayTimeline::Drives::ARRIVAL) saw the car back after the
    # drive: a round trip, whose stop was too short for a visit.
    def goal(drive)
      origin = origin_visit(drive)
      return origin.place if origin && origin.ended_at > drive.ended_at + Car::DayTimeline::Drives::ARRIVAL

      visit = visits.select { origin.nil? || it.started_at > origin.started_at }.min_by { (it.started_at - drive.ended_at).abs }
      visit.place if visit && (visit.started_at - drive.ended_at).abs <= 1.hour
    end

    private

    def origin_visit(drive)
      start = drive.start
      visits
        .select { it.started_at <= start && it.started_at < drive.ended_at && it.ended_at >= start - 1.hour }
        .max_by(&:started_at)
    end
  end
  public_constant :Lane

  BUCKET = Sensor::Query::Helpers::Influx::DailyCurves::BUCKET
  private_constant :BUCKET

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
  # needs the curves of the wallbox (see #charge_spans).
  def start = tap { curves.start(wallbox: sessions.any?(&:wallbox?)) }

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
      Charge.new(session:, spans:, power: power_of(session, spans))
    end
  end

  # The curve of the wallbox over the time of a session at the wallbox,
  # split where the power splitter split its energy
  def power_of(session, spans)
    return [] unless session.wallbox?

    wallbox = curves.wallbox.fetch(timeframe.date, {})
    grid = wallbox[:wallbox_power_grid] if session.kwh_grid
    ChargePower.new(from: spans.first.first, to: spans.last.last, power: wallbox.fetch(:wallbox_power, []), grid:).call
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
  # curves can hold a part that the build did not store yet. Any other
  # session charged over its whole span. The spans end at the edges of the
  # day.
  def charge_spans(session)
    from, to = span_of(session)
    parts = (wallbox_parts[session.started_at.to_i]&.select { |start, _| start < to } if session.wallbox?).presence || [[from, to]]
    [*parts[...-1], [parts.last.first, to]].map { |start, stop| [[start, beginning].max, [stop, timeframe.beginning_of_next].min] }
  end

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
    drives = drives_of(car, soc, recorded)
    charges = [*recorded, *estimated.map { estimate(it, soc:, plug:, drives:, recorded:) }].sort_by { it.span.first }

    Lane.new(car:, drives:, charges:, soc_line: soc_line(soc, drives, charges), visits: (@admin ? visits_of(car) : []), plugged: plugged_of(plug, charges, drives))
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
  # without their places.
  def drives_of(car, soc, charges)
    return [] unless car.sensor?(:car_odometer)

    before, readings = curve(car.sensor_name(:car_odometer)).partition { |time, _| time < beginning }
    stops = visits_of(car).map { [it.started_at, it.ended_at] }
    Drives.new(readings, before: before.last, soc:, stops:, charges: charges.map(&:span)).call
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
  # ChargingSession::Curves.soc_reading?).
  def soc_readings(car)
    return [] unless car.sensor?(:car_battery_soc)

    day_points(curve(car.sensor_name(:car_battery_soc)).select { ChargingSession::Curves.soc_reading?(it.last) })
  end

  # The readings of the plug, the last one before the day at the start of the
  # day
  def plug_readings(car)
    return [] unless car.sensor?(:car_connected)

    day_points(curve(car.sensor_name(:car_connected)))
  end

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

  # The visits of the day
  def visits
    @visits ||=
      PlaceVisit
      .where(car_id: @cars.map(&:id), date: timeframe.date)
      .order(:started_at)
      .preload(:place)
      .to_a
  end

  # [[Time, value], ...] of a sensor of a car up to the end of the data, from
  # its readings before the day, in the time zone of the page. A bucket
  # carries the end of its 5 minutes, so the running bucket ends now.
  def curve(name)
    (curves.cars.dig(timeframe.date, name) || []).filter_map { |time, value| [[time, stops_at].min.in_time_zone, value] if time - BUCKET < stops_at }
  end

  # The curves of the daily build on the day. Each one loads when the
  # timeline first reads it, or all at once after #start. The places come
  # from the visits, so the timeline reads no position of a car. A curve of
  # a car starts with its last reading before the day, so the timeline needs
  # no margin around the day. A session that the power splitter split adds
  # the grid share of the wallbox (see #power_of).
  def curves
    @curves ||= ChargingSession::Curves.new([timeframe.date], cars: @cars, roles: %i[car_battery_soc car_odometer car_connected], margin: 0, split: sessions.any?(&:kwh_grid))
  end
end
