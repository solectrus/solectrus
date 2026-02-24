class Sensor::Definitions::InverterPowerForecastClearsky < Sensor::Definitions::Base
  value unit: :watt, range: (0..), category: :forecast

  color background: 'bg-sensor-forecast-clearsky',
        text: 'text-gray-700 dark:text-gray-300'
end
