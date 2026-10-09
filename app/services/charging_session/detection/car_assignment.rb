# Which car charged a wallbox session. The wallbox does not know the vehicle.
# The candidates of a session are the cars whose period holds its day, and
# the rules apply in this order:
#
# 1. A candidate that reports a position away from home is excluded.
# 2. One candidate reports a connection during the session: that car.
# 3. A candidate that reports no connection is excluded, unless its state of
#    charge rises during the session.
# 4. One candidate remains: that car.
# 5. More than one candidate remains: the car that the heuristics find.
# 6. Otherwise: not assigned.
#
# The position comes from car_latitude and car_longitude of a car, and home
# is the place with the label `home` (see Place::LABELS). Without home or
# without a position during the session, a car gives no sign. A position
# at home is no sign either, because a car at home does not always charge.
#
# The connection comes from car_connected of a car. A car without this sensor
# gives no sign, so it stays a candidate. When two cars report a connection,
# one of them is at another charger, and the heuristics choose between them.
# A car that is offline while it charges can repeat its last state, so a rise
# of its state of charge outweighs a reading of no connection. A car whose
# readings do not change during the session at all is offline, and its
# source only repeats the state before the session, which is no sign.
#
# A car reports late, up to REPORT_LAG after the change. The position and the
# connection therefore count up to REPORT_LAG after the session, so a short
# session at the arrival of a car has the arrival.
#
# A sensor of a car is a state, which holds until its next reading (see the
# DSL `state`). So the state at the start of the session is the last reading
# before it, at any age. A car plugged in at 18:00 that charges at night thus
# reports its connection, also when its source sends only a change.
#
# The heuristics read the car sensors around the session. Two cars cannot
# charge at the same time on one wallbox, so these signs are strong: the
# state of charge of the car rises during the session, the odometer of the
# car does not rise during the session, and all other candidates are
# excluded, so one car remains.
#
# The assignment never makes a guest. With one car and no connection sign,
# each session gets this car, and the user marks a guest charge by hand. A
# session that no candidate was connected to stays not assigned.
class ChargingSession::Detection::CarAssignment
  # How long after a session a reading of the state of charge counts. A car
  # reports its state only while it is online, so a reading long after the
  # session says nothing about it. The curves of a day reach further (see
  # ChargingSession::Curves::MARGIN).
  READING_DISTANCE = 2.hours
  public_constant :READING_DISTANCE

  # How late a car reports a change of its position or its connection: one
  # interval of a source that polls the car
  REPORT_LAG = 15.minutes
  public_constant :REPORT_LAG

  # The sensors that show whether a car is online: one of them changes
  OFFLINE_ROLES = %i[car_battery_soc car_odometer car_connected].freeze
  private_constant :OFFLINE_ROLES

  # A rise of the state of charge below this is noise (percentage points)
  MIN_SOC_RISE = 1
  private_constant :MIN_SOC_RISE

  # A rise of the odometer above this is a drive (km)
  MIN_DRIVE = 0.5
  public_constant :MIN_DRIVE

  # A curve has the mean of 5 minutes, at the end of its bucket (see
  # Sensor::Query::Helpers::Influx::DailyCurves)
  BUCKET = 5.minutes
  private_constant :BUCKET

  # `curves` gives the curve of a car sensor on a date:
  # ->(date, sensor_name) { [[Time, value], ...] }
  # `home` is the place of the wallbox, or nil (see Place.home).
  def initialize(cars, curves:, home: nil)
    @cars = cars
    @curves = curves
    @home = home
  end

  # The car of a session, or nil when it is not assigned
  def car_for(date, from, to)
    candidates = candidates_on(date).reject { away?(date, it, from, to) }
    connections = candidates.index_with { connection_sign(date, it, from, to) }
    connected = candidates.select { connections[it] == :connected }
    return connected.first if connected.one?

    signs = candidates.index_with { soc_sign(date, it, from, to) }
    candidates = connected.presence || candidates.reject { unplugged?(connections[it], signs[it]) }
    return candidates.first if candidates.size <= 1

    charged = candidates.select { signs[it] == :rose }
    return charged.first if charged.one?

    remaining = candidates.reject { signs[it] == :flat || drove?(date, it, from, to) }
    remaining.first if remaining.one?
  end

  private

  attr_reader :cars, :home

  # The cars whose period holds the day
  def candidates_on(date)
    cars.select { it.active_on?(date) }
  end

  # :connected when the car reports a connection during the session,
  # :disconnected when it reports none, nil without a reading. A curve has
  # the end of each bucket, so a reading after the start is during the
  # session, and a reading up to REPORT_LAG after it as well. Without one, or
  # with the readings of an offline car, the state at the start counts.
  def connection_sign(date, car, from, to)
    during = readings(date, :car_connected, car, from + 1, to + REPORT_LAG)
    return sign_before(state_at(date, :car_connected, car, from)) if during.empty? || offline?(date, car, from, to)

    during.any? { it.last.positive? } ? :connected : :disconnected
  end

  # Whether no reading of the car changes during the session: the source
  # repeats the last state of a car that is offline (see OFFLINE_ROLES)
  def offline?(date, car, from, to)
    OFFLINE_ROLES.all? do |role|
      before = state_at(date, role, car, from)&.last
      readings(date, role, car, from + 1, to + REPORT_LAG).all? { it.last == before }
    end
  end

  # Whether a car did not charge because it reports no connection. A rise of
  # its state of charge shows that the reading is old, from a car that is
  # offline while it charges.
  def unplugged?(connection, soc_sign) = connection == :disconnected && soc_sign != :rose

  # The sign of the state at the start of the session: only a connection. A
  # car is plugged in before it charges, so a reading of no connection can be
  # from the drive home and says nothing about the session, like a position
  # before it (see #away?).
  def sign_before(reading)
    :connected if reading&.last&.positive?
  end

  # :rose when the state of charge rises during the session, :flat when it
  # does not, nil without a reading. The state at the start is the last
  # reading before it, at any age.
  def soc_sign(date, car, from, to)
    after = readings(date, :car_battery_soc, car, from, to + READING_DISTANCE)
    before = state_at(date, :car_battery_soc, car, from) || after.first
    return if before.nil? || after.empty?

    after.map(&:last).max - before.last >= MIN_SOC_RISE ? :rose : :flat
  end

  # Whether the car reports positions during the session, and none of them
  # within Place::RADIUS of home. Only a bucket after the start counts,
  # because the reading before can be from the drive home, and a bucket up to
  # REPORT_LAG after the end counts too. A mean of a
  # bucket on a drive is no real position, but a car on a drive does not
  # charge at the wallbox either.
  def away?(date, car, from, to)
    return false unless home

    latitudes = readings(date, :car_latitude, car, from + BUCKET, to + REPORT_LAG).to_h
    positions = readings(date, :car_longitude, car, from + BUCKET, to + REPORT_LAG).filter_map do |time, longitude|
      [latitudes[time], longitude] if latitudes[time]
    end

    positions.any? && positions.none? { home.covers?(*it) }
  end

  # Two cars cannot charge at the same time on one wallbox, so a car that
  # drives during the session did not charge. The odometer at the start is
  # the last reading before it, at any age.
  def drove?(date, car, from, to)
    values = [state_at(date, :car_odometer, car, from), *readings(date, :car_odometer, car, from, to)].compact.map(&:last)
    values.size > 1 && values.max - values.min > MIN_DRIVE
  end

  def readings(date, role, car, from, to)
    @curves.call(date, car.sensor_name(role)).select { |time, _| time.between?(from, to) }
  end

  # The last reading at or before a time, at any age: the curve of a day
  # starts with the last reading before it (see
  # Sensor::Query::Helpers::Influx::DailyCurves)
  def state_at(date, role, car, time)
    @curves.call(date, car.sensor_name(role)).rfind { |reading_time, _| reading_time <= time }
  end
end
