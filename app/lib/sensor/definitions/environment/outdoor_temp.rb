class Sensor::Definitions::OutdoorTemp < Sensor::Definitions::Base
  value unit: :celsius, category: :heatpump, nameable: true

  color hex: '#f87171',
        bg_classes: 'bg-red-400 dark:bg-red-600',
        text_classes: 'text-red-100 dark:text-red-300'

  aggregations stored: %i[avg min max], top10: true

  trend aggregation: :avg, more_is_better: true

  chart { |timeframe| Sensor::Chart::OutdoorTemp.new(timeframe:) }
end
