class AddHeatpumpSensorsToSummaryValues < ActiveRecord::Migration[8.0]
  def up
    add_enum_value :field_enum, :heatpump_heating_power, if_not_exists: true
    add_enum_value :field_enum, :outdoor_temp, if_not_exists: true
    add_enum_value :field_enum, :heatpump_tank_temp, if_not_exists: true
  end

  def down
    # Not possible to remove enum values
  end
end
