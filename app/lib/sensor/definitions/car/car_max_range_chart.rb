# The maximum range on the car page. It shows the selected car, so the
# selection "all" has no such chart (see Sensor::Chart::Concerns::OneCar).
# The values come from car_max_range_<n>, which needs the range and the state
# of charge of the car (see CarMaxRange).
class Sensor::Definitions::CarMaxRangeChart < Sensor::Definitions::Base
  include Sensor::Definitions::CarRoleChart

  def name = :car_max_range

  value unit: :kilometer, category: :car

  chart { |timeframe, cars: nil, **| Sensor::Chart::CarMaxRange.new(timeframe:, cars:) }

  def static_dependencies = Sensor::Cars.dependency(:car_range, :car_battery_soc)
end
