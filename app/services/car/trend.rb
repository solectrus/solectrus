# The trend of a chart of the car page, like car_distance. Such a sensor has
# no daily value of its own, so the base value comes from the report of the
# cars and of the guest sessions (see Car::Report#value).
class Car::Trend < Trend
  def initialize(cars:, guest: false, **)
    super(**)
    @cars = cars
    @guest = guest
  end

  # A car counts from its first day of use, the guest from its first session
  def first_date
    @first_date ||= [*@cars.map(&:active_from), (first_guest_date if @guest)].compact.min
  end

  # Nil without a value, for example without a rate
  def base_value
    @base_value ||= (Car::Report.new(base_timeframe, @cars, guest: @guest).value(sensor.name) if valid?)
  end

  private

  def first_guest_date
    ChargingSession.wallbox.effective.where(car_id: nil, guest: true).minimum(:started_at)&.to_date
  end
end
