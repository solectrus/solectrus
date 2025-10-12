class Sensor::Definitions::HeatpumpHeatingPower < Sensor::Definitions::Base
  value unit: :watt, category: :heatpump

  color hex: '#f97316',
        bg_classes: 'bg-orange-500 dark:bg-orange-700',
        text_classes: 'text-orange-100 dark:text-orange-400'

  aggregations stored: [:sum]

  chart { |timeframe| Sensor::Chart::HeatpumpHeatingPower.new(timeframe:) }

  trend

  requires_permission :heatpump
end
