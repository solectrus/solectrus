class AddSensorsToSummary < ActiveRecord::Migration[7.2]
  def change
    change_table :summaries, bulk: true do |t|
      # Heatpump heating power
      t.column :sum_heatpump_heating_power, :float8
      t.column :max_heatpump_heating_power, :float8
      t.column :avg_heatpump_score, :float8

      # Outdoor temperature
      t.column :min_outdoor_temp, :float8
      t.column :max_outdoor_temp, :float8
      t.column :avg_outdoor_temp, :float8

      # Car driving distance
      t.column :car_driving_distance, :float8

      # Custom power
      t.column :sum_custom_01_power, :float8
      t.column :sum_custom_02_power, :float8
      t.column :sum_custom_03_power, :float8
      t.column :sum_custom_04_power, :float8
      t.column :sum_custom_05_power, :float8
      t.column :sum_custom_06_power, :float8
      t.column :sum_custom_07_power, :float8
      t.column :sum_custom_08_power, :float8
      t.column :sum_custom_09_power, :float8
      t.column :sum_custom_10_power, :float8
    end
  end
end
