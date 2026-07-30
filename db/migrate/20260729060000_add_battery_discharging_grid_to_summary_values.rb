class AddBatteryDischargingGridToSummaryValues < ActiveRecord::Migration[8.1]
  def up
    add_enum_value :field_enum,
                   :battery_discharging_power_grid,
                   if_not_exists: true
  end

  def down
    # Not possible to remove enum values
  end
end
