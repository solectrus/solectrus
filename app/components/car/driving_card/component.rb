# The driving of a period: the distance with its average for each day, the
# driving cost and the two rates per 100 km it comes from.
class Car::DrivingCard::Component < ViewComponent::Base
  include CarChartLink

  def initialize(balance:, timeframe:)
    super()
    @balance = balance
    @timeframe = timeframe
  end

  attr_reader :balance, :timeframe

  # A rate chart needs buckets of a day at least, so on a day the two rate
  # rows open no chart.
  def rate_chart(sensor_name)
    sensor_name if Sensor::Chart::CarRateBase.supports?(timeframe)
  end

  # The distance of the first selected car. Its chart shows each car in the
  # selection "all" (see Sensor::Chart::CarMileage).
  def distance_sensor_name
    Sensor::Cars.sensor_name(:car_mileage, balance.cars.first.id)
  end

  def km_per_day
    distance = Sensor::ValueFormatter.new(balance.car_km_per_day, unit: :kilometer)
    "Ø #{distance}/#{t('sensors.car_km_per_day_unit')}"
  end
end
