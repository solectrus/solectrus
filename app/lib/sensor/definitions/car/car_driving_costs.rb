class Sensor::Definitions::CarDrivingCosts < Sensor::Definitions::Base
  include Sensor::Definitions::CarDrivingChart

  value unit: :money, category: :car

  color background: 'bg-sensor-costs', text: 'text-white dark:text-slate-400'

  trend
end
