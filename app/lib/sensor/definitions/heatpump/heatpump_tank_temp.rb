class Sensor::Definitions::HeatpumpTankTemp < Sensor::Definitions::Base
  value unit: :celsius, category: :heatpump

  color background: gradient(
          from: 30,
          to: 60,
          start: 'bg-orange-400',
          stop: 'bg-red-700',
        ),
        text: 'text-white dark:text-red-100'

  aggregations stored: %i[avg min max], top10: true
  trend aggregation: :avg, more_is_better: true

  chart { |timeframe| Sensor::Chart::HeatpumpTankTemp.new(timeframe:) }

  requires_permission :heatpump
end
