class CreateSummaryValues < ActiveRecord::Migration[8.0]
  OLD_COLUMNS = %w[
    avg_battery_soc
    avg_car_battery_soc
    avg_case_temp
    max_battery_charging_power
    max_battery_discharging_power
    max_battery_soc
    max_car_battery_soc
    max_case_temp
    max_grid_export_power
    max_grid_import_power
    max_heatpump_power
    max_house_power
    max_inverter_power
    max_wallbox_power
    min_battery_soc
    min_car_battery_soc
    min_case_temp
    sum_battery_charging_power
    sum_battery_charging_power_grid
    sum_battery_discharging_power
    sum_custom_power_01
    sum_custom_power_02
    sum_custom_power_03
    sum_custom_power_04
    sum_custom_power_05
    sum_custom_power_06
    sum_custom_power_07
    sum_custom_power_08
    sum_custom_power_09
    sum_custom_power_10
    sum_grid_export_power
    sum_grid_import_power
    sum_heatpump_power
    sum_heatpump_power_grid
    sum_house_power
    sum_house_power_grid
    sum_inverter_power
    sum_inverter_power_forecast
    sum_wallbox_power
    sum_wallbox_power_grid
  ]

  def up
    create_enum :field_enum,
                %w[
                  battery_charging_power
                  battery_charging_power_grid
                  battery_discharging_power
                  battery_soc
                  car_battery_soc
                  case_temp
                  grid_export_power
                  grid_import_power
                  heatpump_power
                  heatpump_power_grid
                  house_power
                  house_power_grid
                  inverter_power
                  inverter_power_forecast
                  wallbox_power
                  wallbox_power_grid
                  custom_power_01
                  custom_power_02
                  custom_power_03
                  custom_power_04
                  custom_power_05
                  custom_power_06
                  custom_power_07
                  custom_power_08
                  custom_power_09
                  custom_power_10
                ]

    create_enum :aggregation_enum, %w[sum max min avg]

    create_table 'summary_values',
                 primary_key: %w[date aggregation field],
                 force: :cascade do |t|
      t.date :date, null: false
      t.enum :field, enum_type: :field_enum, null: false
      t.enum :aggregation, enum_type: :aggregation_enum, null: false
      t.float :value, null: false
    end

    add_foreign_key :summary_values,
                    :summaries,
                    column: :date,
                    primary_key: :date,
                    on_delete: :cascade

    # Index required for Top10 (which are filtered by field and aggregation)
    add_index :summary_values, %i[field aggregation date]

    OLD_COLUMNS.each { |column| remove_column :summaries, column }
  end

  def down
    drop_table :summary_values

    drop_enum :aggregation_enum
    drop_enum :field_enum

    OLD_COLUMNS.each { |column| add_column :summaries, column, :float }
  end
end
