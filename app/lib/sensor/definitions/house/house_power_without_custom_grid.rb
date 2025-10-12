class Sensor::Definitions::HousePowerWithoutCustomGrid < Sensor::Definitions::Base
  value unit: :watt, category: :power_splitter

  color hex: '#dc2626',
        bg_classes: 'bg-red-600 dark:bg-red-800',
        text_classes: 'text-red-100 dark:text-red-400'

  depends_on :house_power_grid, :custom_power_total_grid

  calculate do |house_power_grid:, custom_power_total_grid:, **|
    return unless house_power_grid

    custom_grid_total = custom_power_total_grid || 0
    [house_power_grid - custom_grid_total, 0].max
  end

  aggregations stored: false, computed: [:sum], meta: %i[sum avg]

  requires_permission :power_splitter
end
