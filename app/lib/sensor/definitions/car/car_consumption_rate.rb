class Sensor::Definitions::CarConsumptionRate < Sensor::Definitions::Base
  value unit: :kwh_per_100km, category: :car

  color background: 'bg-sensor-car-consumption', text: 'text-white dark:text-slate-400'

  chart { |timeframe, cars: nil, **| Sensor::Chart::CarConsumptionRate.new(timeframe:, cars:) }

  # The chart builds each rate from a window of daily values (see
  # Sensor::Chart::CarRateBase), so the sensor never carries a scalar value.
  chart_only

  # A rate needs the distance of a car. The energy and the cost can come
  # from the offsite sessions alone, so the wallbox is no condition.
  def static_dependencies = Sensor::Cars.odometer_dependency

  requires_permission :car
end
