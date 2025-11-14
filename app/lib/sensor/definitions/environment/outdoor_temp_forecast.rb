class Sensor::Definitions::OutdoorTempForecast < Sensor::Definitions::Base
  value unit: :celsius, category: :forecast

  chart { |timeframe| Sensor::Chart::OutdoorTempForecastChart.new(timeframe:) }
end
