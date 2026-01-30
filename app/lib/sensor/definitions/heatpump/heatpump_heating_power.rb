class Sensor::Definitions::HeatpumpHeatingPower < Sensor::Definitions::Base
  value unit: :watt, category: :heatpump

  color background: 'bg-orange-500 dark:bg-orange-700',
        text: 'text-white dark:text-orange-100'

  aggregations stored: [:sum], top10: true

  chart { |timeframe| Sensor::Chart::HeatpumpHeatingPower.new(timeframe:) }

  trend

  requires_permission :heatpump
end
