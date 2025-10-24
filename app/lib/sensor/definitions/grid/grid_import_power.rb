class Sensor::Definitions::GridImportPower < Sensor::Definitions::Base
  value unit: :watt, category: :grid

  color hex: '#dc2626',
        bg_classes: 'bg-red-600 dark:bg-red-800/80',
        text_classes: 'text-white dark:text-slate-400'

  icon 'fa-bolt'

  aggregations stored: %i[sum max], top10: true

  chart { |timeframe| Sensor::Chart::GridImportPower.new(timeframe:) }

  trend
end
