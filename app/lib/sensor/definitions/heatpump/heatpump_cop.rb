class Sensor::Definitions::HeatpumpCop < Sensor::Definitions::Base
  value unit: :unitless, category: :heatpump

  color hex: '#0369a1',
        bg_classes: 'bg-sky-700 dark:bg-sky-700',
        text_classes: 'text-sky-200 dark:text-sky-400'

  depends_on :heatpump_power, :heatpump_heating_power

  calculate do |heatpump_power:, heatpump_heating_power:, **|
    return unless heatpump_heating_power
    return if heatpump_power.nil? || heatpump_power.zero?

    heatpump_heating_power.fdiv(heatpump_power).round(2)
  end

  aggregations stored: false, computed: [:avg], meta: [:avg]

  trend aggregation: :avg, more_is_better: true

  chart { |timeframe| Sensor::Chart::HeatpumpCop.new(timeframe:) }

  requires_permission :heatpump
end
