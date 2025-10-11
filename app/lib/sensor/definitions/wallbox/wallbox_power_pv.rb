class Sensor::Definitions::WallboxPowerPv < Sensor::Definitions::Base
  value unit: :watt, category: :power_splitter

  color hex: '#16a34a',
        bg_classes: 'bg-green-600 dark:bg-green-800',
        text_classes: 'text-green-100 dark:text-green-400'

  depends_on :wallbox_power, :wallbox_power_grid

  calculate do |wallbox_power:, wallbox_power_grid:, **|
    return unless wallbox_power && wallbox_power_grid

    [wallbox_power - wallbox_power_grid, 0].max
  end

  aggregations stored: false, computed: [:sum], meta: [:sum]

  requires_permission :power_splitter
end
