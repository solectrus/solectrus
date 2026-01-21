class Sensor::Definitions::CaseTemp < Sensor::Definitions::Base
  value unit: :celsius, category: :battery, nameable: true

  color background: gradient(
          from: 10,
          to: 40,
          start: 'bg-sky-400 dark:bg-sky-600',
          stop: 'bg-red-400 dark:bg-red-600',
        ),
        text: 'text-white dark:text-gray-100'

  aggregations stored: %i[min max avg], computed: [:avg], meta: %i[min max avg], top10: true
  trend aggregation: :avg, more_is_better: false

  chart { |timeframe| Sensor::Chart::CaseTemp.new(timeframe:) }
end
