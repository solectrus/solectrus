class Sensor::Definitions::OutdoorTempForecast < Sensor::Definitions::Base
  value unit: :celsius, category: :forecast

  color background: gradient(
          from: -10,
          to: 40,
          start: 'bg-sky-400 dark:bg-sky-600',
          stop: 'bg-red-400 dark:bg-red-600',
        ),
        text: 'text-red-100 dark:text-red-300'

  chart { |timeframe| Sensor::Chart::OutdoorTempForecast.new(timeframe:) }
end
