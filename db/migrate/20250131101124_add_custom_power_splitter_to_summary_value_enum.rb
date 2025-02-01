class AddCustomPowerSplitterToSummaryValueEnum < ActiveRecord::Migration[8.0]
  def change
    reversible do |dir|
      dir.up do
        SensorConfig::CUSTOM_SENSORS.each do |sensor|
          add_enum_value :field_enum, :"#{sensor}_grid"
        end
      end
    end
  end
end
