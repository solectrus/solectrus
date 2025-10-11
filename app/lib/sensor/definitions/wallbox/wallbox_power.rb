class Sensor::Definitions::WallboxPower < Sensor::Definitions::Base
  value unit: :watt, category: :consumer, nameable: true

  color hex: '#334155',
        bg_classes: 'bg-slate-700 dark:bg-slate-600/50',
        text_classes: 'text-white dark:text-slate-400'

  icon 'fa-car'

  aggregations stored: %i[sum max], top10: true

  chart { |timeframe| Sensor::Chart::WallboxPower.new(timeframe:) }

  trend
end
