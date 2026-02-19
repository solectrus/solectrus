class Sensor::Definitions::HeatpumpHeatingPower < Sensor::Definitions::Base
  value unit: :watt, category: :heatpump

  color background: 'bg-sensor-heatpump-heating',
        text: 'text-white dark:text-slate-400'

  aggregations stored: [:sum], top10: true

  chart { |timeframe| Sensor::Chart::HeatpumpHeatingPower.new(timeframe:) }

  trend

  requires_permission :heatpump
end
