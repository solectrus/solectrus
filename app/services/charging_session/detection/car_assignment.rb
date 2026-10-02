# Which car charged a wallbox session. The wallbox does not know the vehicle.
# The candidates of a session are the cars whose period holds its day, and
# the rules apply in this order:
#
# 1. One candidate: that car.
# 2. More than one candidate: the car that the heuristics find.
# 3. Otherwise: not assigned.
#
# The heuristics read the car sensors around the session. Two cars cannot
# charge at the same time on one wallbox, so these signs are strong: the
# state of charge of the car rises during the session, the odometer of the
# car does not rise during the session, and all other candidates are
# excluded, so one car remains.
#
# Rule 1 never makes a guest. With one car, each session gets this car, and
# the user marks a guest charge by hand.
class ChargingSession::Detection::CarAssignment
  # The largest distance between a reading of a car and its session. A car
  # reports its state only while it is online, so a reading far from the
  # session says nothing about it.
  READING_DISTANCE = 2.hours
  public_constant :READING_DISTANCE

  # A rise of the state of charge below this is noise (percentage points)
  MIN_SOC_RISE = 1
  private_constant :MIN_SOC_RISE

  # A rise of the odometer above this is a drive (km)
  MIN_DRIVE = 0.5
  private_constant :MIN_DRIVE

  # The car sensors that the heuristics read
  ROLES = %i[car_battery_soc car_mileage].freeze
  private_constant :ROLES

  # `curves` gives the curve of a car sensor on a date:
  # ->(date, sensor_name) { [[Time, value], ...] }
  def initialize(cars, curves: nil)
    @cars = cars
    @curves = curves
  end

  attr_reader :cars

  # The cars whose period holds the day
  def candidates_on(date)
    cars.select { it.active_on?(date) }
  end

  # The car sensors that the heuristics read on the given dates: only on a
  # day with more than one candidate
  def sensor_names(dates)
    dates
      .flat_map { candidates_on(it).then { |candidates| candidates.size > 1 ? candidates : [] } }
      .uniq
      .flat_map { |car| ROLES.map { Sensor::Cars.sensor_name(it, car.id) } }
      .select { Sensor::Config.configured?(it) }
  end

  # The car of a session, or nil when it is not assigned
  def car_for(date, from, to)
    candidates = candidates_on(date)
    return candidates.first if candidates.size <= 1

    signs = candidates.index_with { soc_sign(date, it, from, to) }
    charged = candidates.select { signs[it] == :rose }
    return charged.first if charged.one?

    remaining = candidates.reject { signs[it] == :flat || drove?(date, it, from, to) }
    remaining.first if remaining.one?
  end

  private

  # :rose when the state of charge rises during the session, :flat when it
  # does not, nil without a reading near the session
  def soc_sign(date, car, from, to)
    readings = readings(date, :car_battery_soc, car, from - READING_DISTANCE, to + READING_DISTANCE)
    before = readings.rfind { |time, _| time <= from } || readings.first
    after = readings.filter_map { |time, value| value if time >= from }
    return if before.nil? || after.empty?

    after.max - before.last >= MIN_SOC_RISE ? :rose : :flat
  end

  # Two cars cannot charge at the same time on one wallbox, so a car that
  # drives during the session did not charge.
  def drove?(date, car, from, to)
    values = readings(date, :car_mileage, car, from, to).map(&:last)
    values.size > 1 && values.max - values.min > MIN_DRIVE
  end

  def readings(date, role, car, from, to)
    @curves.call(date, Sensor::Cars.sensor_name(role, car.id)).select { |time, _| time.between?(from, to) }
  end
end
