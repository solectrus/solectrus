class Sensor::Definitions::InverterPowerForecastClearsky < Sensor::Definitions::Base
  value unit: :watt, category: :forecast

  color background: 'bg-gray-400 dark:bg-gray-600',
        text: 'text-gray-700 dark:text-gray-300'
end
