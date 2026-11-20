class Sensor::Definitions::HeatpumpHeatingPower < Sensor::Definitions::Base
  value unit: :watt, range: (0..), category: :heatpump

  color background: 'bg-sensor-heatpump-heating',
        text: 'text-white dark:text-slate-400'

  aggregations stored: [:sum], top10: true

  home_pages :heatpump

  chart { |timeframe| Sensor::Chart::HeatpumpHeatingPower.new(timeframe:) }

  # The heat follows the need of the house, so it is neither better nor
  # worse
  trend neutral: true

  requires_permission :heatpump
end
