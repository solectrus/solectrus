class Sensor::Definitions::BatteryChargingPowerPv < Sensor::Definitions::Base
  value unit: :watt, range: (0..), category: :power_splitter

  color background: 'bg-emerald-700 dark:bg-emerald-900/70',
        text: 'text-white dark:text-slate-400'

  depends_on :battery_charging_power, :battery_charging_power_grid

  calculate do |battery_charging_power:, battery_charging_power_grid:, **|
    return unless battery_charging_power && battery_charging_power_grid

    battery_charging_power - battery_charging_power_grid
  end

  aggregations stored: false, computed: [:sum], meta: [:sum]

  requires_permission :power_splitter
end
