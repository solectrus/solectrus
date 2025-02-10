class Add10CustomConsumer < ActiveRecord::Migration[8.0]
  def change
    reversible do |dir|
      dir.up do
        %i[
          custom_power_11
          custom_power_12
          custom_power_13
          custom_power_14
          custom_power_15
          custom_power_16
          custom_power_17
          custom_power_18
          custom_power_19
          custom_power_20
          custom_power_11_grid
          custom_power_12_grid
          custom_power_13_grid
          custom_power_14_grid
          custom_power_15_grid
          custom_power_16_grid
          custom_power_17_grid
          custom_power_18_grid
          custom_power_19_grid
          custom_power_20_grid
        ].each { |sensor| add_enum_value :field_enum, sensor }
      end
    end
  end
end
