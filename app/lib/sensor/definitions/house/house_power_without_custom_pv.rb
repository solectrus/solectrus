class Sensor::Definitions::HousePowerWithoutCustomPv < Sensor::Definitions::Base
  value unit: :watt, category: :power_splitter

  color hex: '#16a34a',
        bg_classes: 'bg-green-600 dark:bg-green-800',
        text_classes: 'text-green-100 dark:text-green-400'

  depends_on :house_power_pv, :custom_power_total_pv

  calculate do |house_power_pv:, custom_power_total_pv:, **|
    return unless house_power_pv

    custom_pv_total = custom_power_total_pv || 0
    [house_power_pv - custom_pv_total, 0].max
  end

  aggregations stored: false, computed: [:sum], meta: %i[sum avg]

  requires_permission :power_splitter
end
