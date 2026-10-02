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

  # The distance of the first selected car. Its chart shows each car in the
  # selection "all" (see Sensor::Chart::CarMileage).
  def distance_sensor_name
    Sensor::Cars.sensor_name(:car_mileage, balance.cars.first.id)
  end

  # The distance loads its chart, where the chart can draw the timeframe
  def distance_wrapper
    classes = 'block min-w-0 text-center'
    chart = chart_sensor_name(distance_sensor_name)
    return [:div, { class: classes }] unless chart

    [:a, { href: chart_link_url(chart), class: "click-animation focus:outline-none #{classes}", data: chart_link_data(chart) }]
  end

  def km_per_day
    distance = Sensor::ValueFormatter.new(balance.car_km_per_day, unit: :kilometer)
    "Ø #{distance}/#{t('sensors.car_km_per_day_unit')}"
  end
end
