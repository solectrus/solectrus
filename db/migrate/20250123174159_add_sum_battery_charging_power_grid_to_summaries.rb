class AddSumBatteryChargingPowerGridToSummaries < ActiveRecord::Migration[8.0]
  def change
    add_column :summaries, :sum_battery_charging_power_grid, :float
  end
end
