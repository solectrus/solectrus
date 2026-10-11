# The state of charge of each candidate car at the start and at the end of a
# wallbox session. The detection does not know yet which car the session
# gets in the end, because a choice of the user wins (see
# ChargingSession::Detection::Persistence), so it reads each candidate.
#
# The state at the start is the last reading before it, at any age. A car
# that is offline during the charge reports its end late, sometimes with a
# stale state in between, so the state at the end is the highest reading up
# to READING_DISTANCE after it. A reading of 0 or less is no reading, because
# some collectors send 0 while the car is offline.
#
# A charge never lowers the state of charge. A state at the end below the
# state at the start therefore gives no states: both are stale readings of a
# car that was offline during the charge.
class ChargingSession::Detection::StateOfCharge
  # `curves` gives the curve of a car sensor on a date:
  # ->(date, sensor_name) { [[Time, value], ...] }
  def initialize(cars, curves:)
    @cars = cars
    @curves = curves
  end

  # { car_id => [soc_from, soc_to] } of the candidates with readings
  def call(date, from, to)
    cars.select { it.active_on?(date) }.to_h { [it.id, of(date, it, from, to)] }.compact
  end

  private

  attr_reader :cars

  def of(date, car, from, to)
    readings = @curves.call(date, car.sensor_name(:car_battery_soc)).select { it.last.positive? }
    before = readings.rfind { |time, _| time <= from }
    after = readings.select { |time, _| time > from && time <= to + ChargingSession::Detection::CarAssignment::READING_DISTANCE }
    return if before.nil? || after.empty?

    soc_from = before.last.round(1)
    soc_to = after.map(&:last).max.round(1)
    [soc_from, soc_to] if soc_to >= soc_from
  end
end
