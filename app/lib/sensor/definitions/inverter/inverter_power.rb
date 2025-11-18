class Sensor::Definitions::InverterPower < Sensor::Definitions::Base
  value unit: :watt, range: (0..), category: :inverter

  color hex: '#16a34a',
        bg_classes: 'bg-green-600 dark:bg-green-800/80',
        text_classes: 'text-white dark:text-slate-400'

  icon 'fa-sun'

  # Conditional dependencies: only use total if inverter_power not configured
  depends_on do
    Sensor::Config.configured?(:inverter_power) ? [] : [:inverter_power_total]
  end

  calculate do |inverter_power: nil, inverter_power_total: nil, **|
    inverter_power || inverter_power_total
  end

  # Override calculated? to check for actual dependencies
  def calculated?
    dependencies.any?
  end

  # Always store inverter_power in summary, whether directly measured or calculated
  aggregations stored: %i[sum max], meta: %i[sum max min avg], top10: true

  chart do |timeframe, variant: nil|
    Sensor::Chart::InverterPower.new(timeframe:, variant:)
  end

  trend more_is_better: true
end
