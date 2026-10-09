# Finds the charges of a car away from the wallbox, as one more step of the
# daily build (see Summary::Steps), and writes them as proposals of offsite
# sessions (see ChargingSession::Proposal).
#
# The sign is a rise of the state of charge in one charge of the car (see
# ChargingSession::OffsiteDetection::CarCurves):
#
# - A step between two readings in which the odometer rises by more than
#   Sensor::Query::Positions::MOVE is no part of a rise, and it ends the
#   rise before it. The odometer can report the end of a drive late, in the
#   first reading of the charge, so only this step goes. Two stops at
#   chargers on one trip give two rises.
# - A reading of the state of charge of 0 or less is no reading. Some
#   collectors send 0 while the car is offline.
# - A rise needs MIN_RISE. A smaller rise down to MIN_CONNECTED_RISE counts
#   only while the car reports a connection, because the connection tells a
#   short charge from noise, for example a new calibration of the battery.
# - A car that reports its connection and is not connected during the whole
#   rise does not charge. Without a reading of the connection, it gives no
#   sign.
# - A rise at home is no offsite charge. There the energy came through the
#   house, or the data of the wallbox has a gap. The position comes from
#   curves of the car, and it ends when the car drives away, like in
#   Sensor::Query::Positions (see CarCurves#position_at).
#
# #call reads InfluxDB without the database, so it can run in a thread of its
# own. #persist compares the rises with the sessions in the database:
#
# - A rise during a wallbox session of the car, or of no car, is that
#   session.
# - A rise that starts up to READING_DISTANCE after the end of such a session
#   is that session too, because a car that is offline during the charge
#   reports the rise late. This does not apply to a car away from home.
# - An offsite session of the car with the mark blocks a rise in its time
#   (see ChargingSession::Proposal#blocked_period), so the build makes no
#   second session of an entered or a dismissed charge.
# - An entered session gets the state of charge and the position of its
#   rise (see ChargingSession::OffsiteDetection::EnteredState).
#
# A rise belongs to the day of its start. The curves reach
# ChargingSession::Curves::MARGIN into the next day, so a charge over
# midnight has its full rise, and the next day skips it.
class ChargingSession::OffsiteDetection
  # The step of the daily build (see Summary::Steps)
  KEY = :offsite_sessions
  public_constant :KEY

  # Bump to build the proposals of each day again
  VERSION = 1
  public_constant :VERSION

  # The proposals keep no change of the user, but a dismissed proposal and
  # an accepted one are rows of the user, so a reset keeps the table
  def self.derived = nil

  # A smaller rise is noise or a short charge (percentage points)
  MIN_RISE = 5
  public_constant :MIN_RISE

  # A smaller rise counts only while the car reports a connection, which
  # tells a short charge from noise (percentage points)
  MIN_CONNECTED_RISE = 3
  public_constant :MIN_CONNECTED_RISE

  # A curve has the mean of 5 minutes, at the end of its bucket (see
  # Sensor::Query::Helpers::Influx::DailyCurves)
  BUCKET = Sensor::Query::Helpers::Influx::DailyCurves::BUCKET
  private_constant :BUCKET

  # A rise of the state of charge of a car, at a position away from home or
  # without a position
  Rise = Data.define(:car_id, :started_at, :ended_at, :soc_from, :soc_to, :latitude, :longitude) do
    def date = started_at.in_time_zone.to_date

    def located? = !latitude.nil?

    def overlap?(from, to) = started_at < to && ended_at > from

    # Whether the rise lies in the time of an offsite session of its car
    # with the mark (see ChargingSession::Proposal#blocked_period)
    def blocked_by?(session)
      period = session.blocked_period
      session.car_id == car_id && overlap?(period.begin, period.end)
    end
  end
  public_constant :Rise

  # The state of charge needs the permission of the sensors, like each query
  def self.enabled?
    Sensor::Cars.configured_numbers.any? { Sensor::Config.exists?(Sensor::Cars.sensor_name(:car_battery_soc, it)) }
  end

  # `curves` are the curves of the cars, which the detection of the wallbox
  # sessions reads as well (see ChargingSession::Curves)
  def initialize(dates, cars: Car.configured, curves: ChargingSession::Curves.new(dates, cars:))
    @dates = dates.sort
    @curves = curves
    @cars = cars.select { it.sensor?(:car_battery_soc) && it.active_during?(@dates.first..@dates.last) }
    @located = @cars.select(&:located?).to_set(&:id)
    @home = Place.home
  end

  attr_reader :dates

  # { date => [Rise, ...] }, without a write. A car has only the rises on the
  # days of its period of use.
  def call
    rises = cars.flat_map { |car| rises_of(car).select { car.active_on?(it.date) } }
    dates.index_with { |date| rises.select { it.date == date } }
  end

  # Writes the result of #call: the proposals of each day, in place of the
  # old ones, and the state of charge of the entered sessions of each day
  def persist(results)
    ChargingSession.proposals.where(started_at: dates.map(&:all_day)).delete_all

    wallbox = nearby(results.values.flatten, ChargingSession.wallbox.where(guest: false))
    rises = results.values.flatten.reject { wallbox_charge?(it, wallbox) }
    EnteredState.new(ChargingSession.offsite.effective.where(started_at: dates.map(&:all_day)).to_a, rises).call

    blocking = nearby(rises, ChargingSession.offsite.where(assigned_manually: true))
    rows = rises.reject { |rise| blocking.any? { rise.blocked_by?(it) } }.map { row(it) }
    ChargingSession.insert_all(rows) if rows.any? # rubocop:disable Rails/SkipsModelValidations
  end

  private

  attr_reader :cars, :located, :home, :curves

  def rises_of(car)
    car_curves = CarCurves.new(
      car:,
      soc: curve(car, :car_battery_soc).select { it.last.positive? },
      odometer: curve(car, :car_odometer),
      connected: curve(car, :car_connected),
      latitude: located.include?(car.id) ? curve(car, :car_latitude) : [],
      longitude: located.include?(car.id) ? curve(car, :car_longitude) : [],
    )

    car_curves.charges.filter_map do |steps|
      steps = steps.select { |_, _, rise| rise.positive? }
      rise_of(car_curves, steps) if counts?(car_curves, steps)
    end
  end

  # Whether the rise is a charge: MIN_RISE, or MIN_CONNECTED_RISE while the
  # car reports a connection. A car that reports no connection does not
  # charge.
  def counts?(curves, steps)
    rise = steps.sum(&:last)
    return false if rise < MIN_CONNECTED_RISE

    sign = curves.connection(steps.first.first, steps.last.second)
    sign == :connected || (sign.nil? && rise >= MIN_RISE)
  end

  def rise_of(curves, steps)
    from = steps.first.first
    to = steps.last.second
    position = curves.position_at(from + ((to - from) / 2))
    return if at_home?(position)

    soc_from = curves.soc_at(from)
    Rise.new(
      car_id: curves.car.id,
      started_at: from,
      ended_at: to,
      soc_from: soc_from.round(1),
      soc_to: [soc_from + steps.sum(&:last), 100].min.round(1),
      latitude: position&.latitude,
      longitude: position&.longitude,
    )
  end

  def at_home?(position)
    return false unless position && home

    home.covers?(position.latitude, position.longitude)
  end

  # The readings of a car sensor on all days of the curves, each at the
  # start of its bucket. The positions come from the curves as well, because
  # a query of Sensor::Query::Positions for each car took ten times as long.
  def curve(car, role)
    name = car.sensor_name(role)
    curves.cars.values.flat_map { it[name] || [] }.uniq(&:first).sort_by(&:first).map { |time, value| [time - BUCKET, value] }
  end

  # The sessions of the scope around the rises
  def nearby(rises, scope)
    return [] if rises.empty?

    scope.where(started_at: (rises.map(&:started_at).min - 1.day)..(rises.map(&:ended_at).max + 1.day)).to_a
  end

  # Whether the rise belongs to a wallbox session of the car or of no car
  def wallbox_charge?(rise, sessions)
    sessions.any? do |session|
      next false unless session.car_id.nil? || session.car_id == rise.car_id

      rise.overlap?(session.started_at, session.ended_at) ||
        (!away?(rise) && reported_late?(rise, session))
    end
  end

  # A rise at home has no proposal, so a rise with a position is away
  # from home. Without home, the position says nothing.
  def away?(rise) = home.present? && rise.located?

  def reported_late?(rise, session)
    rise.started_at.between?(session.ended_at, session.ended_at + ChargingSession::Detection::CarAssignment::READING_DISTANCE)
  end

  def row(rise)
    car = cars.find { it.id == rise.car_id }

    rise.to_h.merge(
      kind: 'offsite',
      origin: 'detection',
      kwh: ChargingSession.estimate(rise.soc_from, rise.soc_to, car.battery_kwh),
      assigned_manually: false,
      guest: false,
      dismissed: false,
    )
  end
end
