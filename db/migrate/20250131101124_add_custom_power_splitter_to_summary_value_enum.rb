class AddCustomPowerSplitterToSummaryValueEnum < ActiveRecord::Migration[8.0]
  def change
    reversible do |dir|
      dir.up do
        add_enum_value :field_enum, :custom_power_01_grid
        add_enum_value :field_enum, :custom_power_02_grid
        add_enum_value :field_enum, :custom_power_03_grid
        add_enum_value :field_enum, :custom_power_04_grid
        add_enum_value :field_enum, :custom_power_05_grid
        add_enum_value :field_enum, :custom_power_06_grid
        add_enum_value :field_enum, :custom_power_07_grid
        add_enum_value :field_enum, :custom_power_08_grid
        add_enum_value :field_enum, :custom_power_09_grid
        add_enum_value :field_enum, :custom_power_10_grid
      end
    end
  end
end
