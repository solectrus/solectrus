class Sensor::Definitions::CarConsumptionRate < Sensor::Definitions::Base
  include Sensor::Definitions::CarDrivingChart

  value unit: :kwh_per_100km, category: :car

  color background: 'bg-sensor-car-consumption', text: 'text-white dark:text-slate-400'

  trend aggregation: :avg
end
