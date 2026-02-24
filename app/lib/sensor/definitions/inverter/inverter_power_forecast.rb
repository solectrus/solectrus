class Sensor::Definitions::InverterPowerForecast < Sensor::Definitions::Base
  value unit: :watt, range: (0..), category: :forecast

  color background: 'bg-sensor-pv',
        text: 'text-white dark:text-slate-400',
        hatch_fill: true

  aggregations stored: [:sum]

  chart { |timeframe| Sensor::Chart::InverterPowerForecast.new(timeframe:) }
end
