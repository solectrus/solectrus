class Sensor::Definitions::GridExportPower < Sensor::Definitions::Base
  value unit: :watt, category: :grid

  color hex: '#16a34a',
        bg_classes: 'bg-green-600 dark:bg-green-800/80',
        text_classes: 'text-white dark:text-slate-400'

  icon 'fa-bolt'

  aggregations stored: %i[sum max], top10: true

  chart { |timeframe| Sensor::Chart::GridExportPower.new(timeframe:) }

  trend more_is_better: true
end
