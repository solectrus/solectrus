# The upper limit of the variability band around the PV forecast
class Sensor::Definitions::InverterPowerForecastMax < Sensor::Definitions::Base
  value unit: :watt, range: (0..), category: :forecast

  color background: 'bg-sensor-pv',
        text: 'text-white dark:text-slate-400'
end
