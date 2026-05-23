class Sensor::Definitions::OutdoorTempForecast < Sensor::Definitions::Base
  value unit: :celsius, category: :forecast

  color background: gradient(
          stops: {
            -15 => 'bg-indigo-900',
            5 => 'bg-blue-700 dark:bg-blue-800',
            18 => 'bg-slate-400 dark:bg-slate-600',
            32 => 'bg-red-700 dark:bg-red-800',
            40 => 'bg-rose-900',
          },
        ),
        text: 'text-red-100 dark:text-red-300'

  chart { |timeframe| Sensor::Chart::OutdoorTempForecast.new(timeframe:) }
end
