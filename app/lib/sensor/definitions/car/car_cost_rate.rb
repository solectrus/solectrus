class Sensor::Definitions::CarCostRate < Sensor::Definitions::Base
  value unit: :money_per_100km, category: :car

  color background: 'bg-sensor-car-cost-rate', text: 'text-white dark:text-slate-400'

  chart { |timeframe, cars: nil, **| Sensor::Chart::CarDriving.new(timeframe:, cars:, metric: :car_cost_rate) }

  # The chart builds each column from the window around each day (see
  # Sensor::Chart::CarDriving), so the sensor never carries a scalar value.
  chart_only

  # A rate needs the distance of a car. The energy and the cost can come
  # from the offsite sessions alone, so the wallbox is no condition.
  def static_dependencies = Sensor::Cars.dependency(:car_odometer)

  requires_permission :car
end
