class Sensor::Definitions::HeatpumpTankTemp < Sensor::Definitions::Base
  value unit: :celsius, category: :heatpump

  color background: gradient(
          from: 30,
          to: 60,
          start: 'bg-orange-400 dark:bg-orange-800',
          stop: 'bg-red-700 dark:bg-red-900',
        ),
        text: 'text-white dark:text-red-100'

  aggregations stored: %i[avg min max], top10: true
  # The hot water follows its set point, so it is neither better nor worse
  trend aggregation: :avg, neutral: true

  home_pages :heatpump

  chart { |timeframe| Sensor::Chart::HeatpumpTankTemp.new(timeframe:) }

  requires_permission :heatpump
end
