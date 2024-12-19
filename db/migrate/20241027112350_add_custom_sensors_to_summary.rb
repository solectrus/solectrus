class AddCustomSensorsToSummary < ActiveRecord::Migration[7.2]
  def change
    change_table :summaries, bulk: true do |t|
      t.column :sum_custom_power_01, :float8
      t.column :sum_custom_power_02, :float8
      t.column :sum_custom_power_03, :float8
      t.column :sum_custom_power_04, :float8
      t.column :sum_custom_power_05, :float8
      t.column :sum_custom_power_06, :float8
      t.column :sum_custom_power_07, :float8
      t.column :sum_custom_power_08, :float8
      t.column :sum_custom_power_09, :float8
      t.column :sum_custom_power_10, :float8
    end
  end
end
