class Sensor::Definitions::HousePowerWithoutCustom < Sensor::Definitions::Base
  value unit: :watt, category: :consumer

  color hex: '#64748b',
        bg_classes: 'bg-slate-500 dark:bg-slate-700',
        text_classes: 'text-slate-100 dark:text-slate-400'

  icon 'fa-home'

  depends_on :house_power, :custom_power_total

  calculate do |house_power:, custom_power_total:, **|
    return unless house_power
    return house_power unless custom_power_total

    [house_power - custom_power_total, 0].max
  end

  aggregations stored: false, computed: [:sum], meta: [:sum]

  chart { |timeframe| Sensor::Chart::HousePowerWithoutCustom.new(timeframe:) }
end
