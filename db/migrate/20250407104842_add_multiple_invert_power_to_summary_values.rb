class AddMultipleInvertPowerToSummaryValues < ActiveRecord::Migration[8.0]
  def change
    reversible do |dir|
      dir.up do
        execute "ALTER TYPE field_enum RENAME VALUE 'balcony_inverter_power' TO 'inverter_power_1';"

        add_enum_value :field_enum, :inverter_power_2, if_not_exists: true
        add_enum_value :field_enum, :inverter_power_3, if_not_exists: true
        add_enum_value :field_enum, :inverter_power_4, if_not_exists: true
        add_enum_value :field_enum, :inverter_power_5, if_not_exists: true
      end

      dir.down do
        execute "ALTER TYPE field_enum RENAME VALUE 'inverter_power_1' TO 'balcony_inverter_power';"
      end
    end
  end
end
