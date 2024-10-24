class CreateSummaries < ActiveRecord::Migration[7.2]
  def change
    create_table :summaries, id: false do |t|
      # Single day (Primary Key)
      t.date :date, null: false, primary_key: true

      # Sensors
      t.column :sum_inverter_power, :float8
      t.column :sum_inverter_power_forecast, :float8
      t.column :sum_house_power, :float8
      t.column :sum_heatpump_power, :float8
      t.column :sum_grid_import_power, :float8
      t.column :sum_grid_export_power, :float8
      t.column :sum_battery_charging_power, :float8
      t.column :sum_battery_discharging_power, :float8
      t.column :sum_wallbox_power, :float8

      # Max
      t.column :max_inverter_power, :float8
      t.column :max_house_power, :float8
      t.column :max_heatpump_power, :float8
      t.column :max_grid_import_power, :float8
      t.column :max_grid_export_power, :float8
      t.column :max_battery_charging_power, :float8
      t.column :max_battery_discharging_power, :float8
      t.column :max_wallbox_power, :float8

      # Min/Max
      t.column :min_battery_soc, :float8
      t.column :min_car_battery_soc, :float8
      t.column :min_case_temp, :float8

      t.column :max_battery_soc, :float8
      t.column :max_car_battery_soc, :float8
      t.column :max_case_temp, :float8

      # Average
      t.column :avg_battery_soc, :float8
      t.column :avg_car_battery_soc, :float8
      t.column :avg_case_temp, :float8

      # PowerSplitter
      t.column :sum_house_power_grid, :float8
      t.column :sum_wallbox_power_grid, :float8
      t.column :sum_heatpump_power_grid, :float8

      # Created at and updated at
      t.timestamps
    end

    add_index :summaries, :updated_at
  end
end
