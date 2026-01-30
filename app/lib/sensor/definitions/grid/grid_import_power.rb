class Sensor::Definitions::GridImportPower < Sensor::Definitions::Base
  value unit: :watt, category: :grid

  color background: 'bg-red-700/80 dark:bg-red-800/60',
        text: 'text-white dark:text-slate-400'

  icon 'fa-bolt'

  aggregations stored: %i[sum max], top10: true

  chart { |timeframe| Sensor::Chart::GridImportPower.new(timeframe:) }

  trend
end
