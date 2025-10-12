class Sensor::Definitions::SelfConsumptionQuote < Sensor::Definitions::Base
  value unit: :percent

  color hex: '#15803d',
        bg_classes: 'bg-green-700 dark:bg-green-900',
        text_classes: 'text-green-200 dark:text-green-400'

  depends_on :self_consumption, :inverter_power

  calculate do |self_consumption:, inverter_power:, **|
    return unless self_consumption && inverter_power
    return if inverter_power < 50

    (self_consumption * 100.0 / inverter_power).clamp(0, 100).round
  end

  aggregations stored: false, computed: [:avg], meta: [:avg]

  chart { |timeframe| Sensor::Chart::SelfConsumptionQuote.new(timeframe:) }
end
