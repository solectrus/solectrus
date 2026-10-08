class Sensor::Definitions::CarCostRate < Sensor::Definitions::Base
  include Sensor::Definitions::CarDrivingChart

  value unit: :money_per_100km, category: :car

  color background: 'bg-sensor-car-cost-rate', text: 'text-white dark:text-slate-400'
end
