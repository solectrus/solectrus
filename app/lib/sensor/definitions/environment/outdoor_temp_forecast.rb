class Sensor::Definitions::OutdoorTempForecast < Sensor::Definitions::Base
  value unit: :celsius, category: :forecast

  color hex: '#f87171',
        bg_classes: 'bg-red-400 dark:bg-red-600',
        text_classes: 'text-red-100 dark:text-red-300'

  chart { |timeframe| Sensor::Chart::OutdoorTempForecast.new(timeframe:) }
end
