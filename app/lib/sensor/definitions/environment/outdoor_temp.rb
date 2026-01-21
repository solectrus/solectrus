class Sensor::Definitions::OutdoorTemp < Sensor::Definitions::Base
  value unit: :celsius, category: :heatpump, nameable: true

  color background: gradient(
          from: -10,
          to: 37,
          start: 'bg-blue-400 dark:bg-sky-600',
          stop: 'bg-red-400 dark:bg-red-600',
        ),
        text: 'text-white dark:text-gray-100'

  aggregations stored: %i[avg min max], top10: true

  trend aggregation: :avg, more_is_better: true

  chart { |timeframe| Sensor::Chart::OutdoorTemp.new(timeframe:) }
end
