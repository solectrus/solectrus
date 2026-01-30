class Sensor::Definitions::WallboxPowerPv < Sensor::Definitions::Base
  value unit: :watt, category: :power_splitter

  color background: 'bg-emerald-600 dark:bg-emerald-800',
        text: 'text-emerald-100 dark:text-emerald-400'

  depends_on :wallbox_power, :wallbox_power_grid

  calculate do |wallbox_power:, wallbox_power_grid:, **|
    return unless wallbox_power && wallbox_power_grid

    [wallbox_power - wallbox_power_grid, 0].max
  end

  aggregations stored: false, computed: [:sum], meta: [:sum]

  requires_permission :power_splitter
end
