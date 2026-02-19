class Sensor::Definitions::HousePowerWithoutCustomPv < Sensor::Definitions::Base
  value unit: :watt, range: (0..), category: :power_splitter

  color background: 'bg-sensor-pv',
        text: 'text-white dark:text-slate-400'

  depends_on :house_power_pv, :custom_power_total_pv

  calculate do |house_power_pv:, custom_power_total_pv:, **|
    return unless house_power_pv

    custom_pv_total = custom_power_total_pv || 0
    [house_power_pv - custom_pv_total, 0].max
  end

  aggregations stored: false, computed: [:sum], meta: %i[sum avg]

  requires_permission :power_splitter
end
