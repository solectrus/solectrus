# The distance on the car page: a part for each selected car.
# The values come from car_odometer_<n> (see CarOdometer). The sensor has no
# number, because the car select above the chart selects the cars.
class Sensor::Definitions::CarDistanceChart < Sensor::Definitions::Base
  include Sensor::Definitions::CarRoleChart

  def name = :car_distance

  def car_role = :car_odometer

  value unit: :kilometer, category: :car

  chart { |timeframe, cars: nil, **| Sensor::Chart::CarDistance.new(timeframe:, cars:) }
end
