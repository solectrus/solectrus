class Sensor::Definitions::CaseTemp < Sensor::Definitions::Base
  value unit: :celsius, category: :battery, nameable: true

  # Up to 25 degrees is comfortable, from 45 it gets hot
  color background: gradient(
          from: 25,
          to: 45,
          start: 'bg-blue-500 dark:bg-blue-800',
          stop: 'bg-red-500 dark:bg-red-800',
        ),
        text: 'text-white dark:text-gray-100'

  aggregations stored: %i[min max avg], computed: [:avg], meta: %i[min max avg], top10: true
  trend aggregation: :avg, more_is_better: false

  home_pages :balance

  chart { |timeframe| Sensor::Chart::CaseTemp.new(timeframe:) }
end
