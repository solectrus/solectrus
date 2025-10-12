class Sensor::Definitions::InverterPowerForecast < Sensor::Definitions::Base
  value unit: :watt, category: :forecast

  color hex: '#cbd5e1',
        bg_classes: 'bg-slate-300 dark:bg-slate-500',
        text_classes: 'text-slate-700 dark:text-slate-300'

  aggregations stored: [:sum]
end
