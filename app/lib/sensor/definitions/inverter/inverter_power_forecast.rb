class Sensor::Definitions::InverterPowerForecast < Sensor::Definitions::Base
  value unit: :watt, category: :forecast

  color background: 'bg-slate-300 dark:bg-slate-500',
        text: 'text-slate-700 dark:text-slate-300'

  aggregations stored: [:sum]

  chart { |timeframe| Sensor::Chart::InverterPowerForecast.new(timeframe:) }
end
