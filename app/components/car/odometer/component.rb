# The odometer of the car as a mechanical counter: one box for each digit,
# with six digits at least. A click loads the distance chart.
class Car::Odometer::Component < ViewComponent::Base
  include CarChartLink

  MIN_DIGITS = 6
  private_constant :MIN_DIGITS

  def initialize(value:, car:, timeframe:)
    super()
    @value = value
    @car = car
    @timeframe = timeframe
  end

  attr_reader :value, :car, :timeframe

  def sensor_name = Sensor::Cars.sensor_name(:car_mileage, car.id)

  def render?
    value.present?
  end

  def digits
    value.round.to_s.rjust(MIN_DIGITS, '0').chars
  end
end
