class AddBalconyInverterPowerToSummaryValueFieldEnum < ActiveRecord::Migration[
  8.0
]
  def change
    reversible do |dir|
      dir.up { add_enum_value :field_enum, :balcony_inverter_power }
    end
  end
end
