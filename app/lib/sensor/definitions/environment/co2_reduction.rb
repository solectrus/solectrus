class Sensor::Definitions::Co2Reduction < Sensor::Definitions::Base
  value unit: :gram

  color hex: '#0284c7',
        bg_classes: 'bg-sky-600 dark:bg-sky-800',
        text_classes: 'text-sky-700 dark:text-sky-400'

  icon 'fa-leaf'

  depends_on :inverter_power

  calculate do |inverter_power:, **|
    return unless inverter_power

    inverter_power_kwh = inverter_power / 1000.0
    co2_factor = Rails.application.config.x.co2_emission_factor

    (inverter_power_kwh * co2_factor).round
  end

  aggregations stored: false, computed: [:sum], meta: %i[sum avg min max], top10: true

  chart { |timeframe| Sensor::Chart::Co2Reduction.new(timeframe:) }

  def sql_calculation
    co2_factor = Rails.application.config.x.co2_emission_factor
    "COALESCE(inverter_power_sum, 0) * #{co2_factor} / 1000.0"
  end
end
