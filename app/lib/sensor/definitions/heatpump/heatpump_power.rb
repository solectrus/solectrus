class Sensor::Definitions::HeatpumpPower < Sensor::Definitions::Base
  value unit: :watt, category: :consumer, nameable: true

  color hex: '#475569',
        bg_classes: 'bg-slate-600 dark:bg-slate-600/70',
        text_classes: 'text-white dark:text-slate-400'

  icon 'fa-fan'

  aggregations stored: %i[sum max], top10: true

  chart { |timeframe| Sensor::Chart::HeatpumpPower.new(timeframe:) }

  trend
end
