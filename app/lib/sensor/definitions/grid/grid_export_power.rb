class Sensor::Definitions::GridExportPower < Sensor::Definitions::Base
  value unit: :watt, category: :grid

  color hex: '#16a34a',
        bg_classes: 'bg-green-600 dark:bg-green-800/80',
        text_classes: 'text-white dark:text-slate-400'

  icon 'fa-bolt'

  aggregations stored: %i[sum max], top10: true

  trend more_is_better: true
end
