class Sensor::Definitions::InverterPowerDifference < Sensor::Definitions::Base
  value unit: :watt, category: :inverter

  color hex: '#1f3b3c',
        bg_classes: 'bg-green-900/50',
        text_classes: 'text-white dark:text-slate-400'

  depends_on :inverter_power, :inverter_power_total

  calculate do |inverter_power:, inverter_power_total:, **|
    return unless inverter_power

    difference = (inverter_power - (inverter_power_total || 0)).clamp(0..)

    # Suppress very small differences (< 1% of total production or < 5 W)
    # These are likely rounding errors or minimal inaccuracies
    return if difference < 5
    return if difference.fdiv(inverter_power) <= 0.01

    difference
  end

  aggregations stored: false, computed: [:sum], meta: [:sum]
end
