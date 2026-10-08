# The trend of a chart of the car page, like car_distance. Such a sensor has
# no daily value of its own, so the base value comes from the report of the
# cars (see Car::Report#value).
class Car::Trend < Trend
  def initialize(cars:, **)
    super(**)
    @cars = cars
  end

  # A car counts from its first day of use
  def first_date = @cars.map(&:active_from).min

  # Nil without a value, for example without a rate
  def base_value
    @base_value ||= (Car::Report.new(base_timeframe, @cars).value(sensor.name) if valid?)
  end
end
