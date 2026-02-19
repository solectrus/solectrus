class Sensor::Definitions::SelfConsumptionQuote < Sensor::Definitions::Base
  value unit: :percent

  color background: 'bg-sensor-autarky',
        text: 'text-white dark:text-slate-400'

  depends_on :self_consumption, :inverter_power

  calculate do |self_consumption:, inverter_power:, **|
    return unless self_consumption && inverter_power
    return if inverter_power < 50

    (self_consumption * 100.0 / inverter_power).clamp(0, 100).round
  end

  aggregations stored: false, computed: [:avg], meta: [:avg]

  chart { |timeframe| Sensor::Chart::SelfConsumptionQuote.new(timeframe:) }
end
