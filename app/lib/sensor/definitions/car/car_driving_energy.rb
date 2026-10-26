class Sensor::Definitions::CarDrivingEnergy < Sensor::Definitions::Base
  include Sensor::Definitions::CarDrivingChart

  value unit: :watt, category: :car

  color background: 'bg-sensor-car-consumption', text: 'text-white dark:text-slate-400'

  trend
end
