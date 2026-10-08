# The state of charge on the car page. It shows the selected car, so the
# selection "all" has no such chart (see Sensor::Chart::Concerns::OneCar).
# The values come from car_battery_soc_<n> (see CarBatterySoc).
class Sensor::Definitions::CarBatterySocChart < Sensor::Definitions::Base
  include Sensor::Definitions::CarRoleChart

  def name = :car_battery_soc

  value unit: :percent, category: :car

  chart { |timeframe, cars: nil, **| Sensor::Chart::CarBatterySoc.new(timeframe:, cars:) }
end
