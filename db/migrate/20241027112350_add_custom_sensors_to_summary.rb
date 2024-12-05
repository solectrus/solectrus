class AddCustomSensorsToSummary < ActiveRecord::Migration[7.2]
  def change
    change_table :summaries, bulk: true do |t|
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
