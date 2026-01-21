class Sensor::Definitions::CaseTemp < Sensor::Definitions::Base
  value unit: :celsius, category: :battery, nameable: true

  color hex: '#ef4444',
        bg_classes: 'bg-red-500 dark:bg-red-700',
        text_classes: 'text-red-100 dark:text-red-400'

  aggregations stored: %i[min max avg], computed: [:avg], meta: %i[min max avg], top10: true
  trend aggregation: :avg, more_is_better: false

  chart { |timeframe| Sensor::Chart::CaseTemp.new(timeframe:) }
end
