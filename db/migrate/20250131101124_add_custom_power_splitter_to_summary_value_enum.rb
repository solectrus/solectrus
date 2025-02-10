class AddCustomPowerSplitterToSummaryValueEnum < ActiveRecord::Migration[8.0]
  def change
    reversible do |dir|
      dir.up do
        SensorConfig::CUSTOM_SENSORS
          .first(10)
          .each { |sensor| add_enum_value :field_enum, :"#{sensor}_grid" }
      end
    end
  end
end
