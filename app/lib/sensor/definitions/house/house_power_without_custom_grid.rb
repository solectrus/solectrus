class Sensor::Definitions::HousePowerWithoutCustomGrid < Sensor::Definitions::Base
  value unit: :watt, range: (0..), category: :power_splitter

  color background: 'bg-red-700/80 dark:bg-red-800/60',
        text: 'text-white dark:text-slate-400'

  depends_on :house_power_grid, :custom_power_total_grid

  calculate do |house_power_grid:, custom_power_total_grid:, **|
    return unless house_power_grid

    custom_grid_total = custom_power_total_grid || 0
    [house_power_grid - custom_grid_total, 0].max
  end

  aggregations stored: false, computed: [:sum], meta: %i[sum avg]

  requires_permission :power_splitter
end
