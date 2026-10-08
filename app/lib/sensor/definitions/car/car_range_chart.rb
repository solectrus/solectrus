# The range on the car page. It shows the selected car, so the selection
# "all" has no such chart (see Sensor::Chart::Concerns::OneCar). The values
# come from car_range_<n> (see CarRange).
class Sensor::Definitions::CarRangeChart < Sensor::Definitions::Base
  include Sensor::Definitions::CarRoleChart

  def name = :car_range

  value unit: :kilometer, category: :car

  chart { |timeframe, cars: nil, **| Sensor::Chart::CarRange.new(timeframe:, cars:) }
end
