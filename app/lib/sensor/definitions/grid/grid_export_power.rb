class Sensor::Definitions::GridExportPower < Sensor::Definitions::Base
  value unit: :watt, category: :grid

  color background: 'bg-emerald-600 dark:bg-emerald-800/80',
        text: 'text-white dark:text-slate-400'

  icon 'fa-bolt'

  aggregations stored: %i[sum max], top10: true

  chart { |timeframe| Sensor::Chart::GridExportPower.new(timeframe:) }

  trend more_is_better: true
end
