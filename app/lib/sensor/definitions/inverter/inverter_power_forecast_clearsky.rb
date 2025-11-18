class Sensor::Definitions::InverterPowerForecastClearsky < Sensor::Definitions::Base
  value unit: :watt, category: :forecast

  color hex: '#9ca3af',
        bg_classes: 'bg-gray-400 dark:bg-gray-600',
        text_classes: 'text-gray-700 dark:text-gray-300'
end
