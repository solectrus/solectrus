class Sensor::Definitions::WallboxPowerPv < Sensor::Definitions::Base
  value unit: :watt, category: :power_splitter

  color background: 'bg-sensor-pv',
        text: 'text-white dark:text-slate-400'

  depends_on :wallbox_power, :wallbox_power_grid

  calculate do |wallbox_power:, wallbox_power_grid:, **|
    return unless wallbox_power && wallbox_power_grid

    [wallbox_power - wallbox_power_grid, 0].max
  end

  aggregations stored: false, computed: [:sum], meta: [:sum]

  requires_permission :power_splitter
end
