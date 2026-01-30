class Sensor::Definitions::HousePowerWithoutCustomPv < Sensor::Definitions::Base
  value unit: :watt, range: (0..), category: :power_splitter

  color background: 'bg-emerald-600 dark:bg-emerald-800',
        text: 'text-emerald-100 dark:text-emerald-400'

  depends_on :house_power_pv, :custom_power_total_pv

  calculate do |house_power_pv:, custom_power_total_pv:, **|
    return unless house_power_pv

    custom_pv_total = custom_power_total_pv || 0
    [house_power_pv - custom_pv_total, 0].max
  end

  aggregations stored: false, computed: [:sum], meta: %i[sum avg]

  requires_permission :power_splitter
end
