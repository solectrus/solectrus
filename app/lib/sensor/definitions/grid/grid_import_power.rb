class Sensor::Definitions::GridImportPower < Sensor::Definitions::Base
  value unit: :watt, category: :grid

  color background: 'bg-sensor-grid',
        text: 'text-white dark:text-slate-400'

  icon 'fa-bolt'

  aggregations stored: %i[sum max], top10: true

  chart { |timeframe| Sensor::Chart::GridImportPower.new(timeframe:) }

  trend
end
