class Sensor::Definitions::CarDrivingCosts < Sensor::Definitions::Base
  value unit: :money, category: :car

  color background: 'bg-sensor-costs', text: 'text-white dark:text-slate-400'

  home_pages :cars

  chart { |timeframe, cars: nil, **| Sensor::Chart::CarDrivingCosts.new(timeframe:, cars:) }

  # The chart builds each cost from the distance and the rate of a window
  # (see Sensor::Chart::CarDrivingCosts), so the sensor never carries a
  # scalar value.
  chart_only

  # A rate needs the distance of a car. The energy and the cost can come
  # from the offsite sessions alone, so the wallbox is no condition.
  def static_dependencies = Sensor::Cars.odometer_dependency

  requires_permission :car
end
