# == Schema Information
#
# Table name: summary_values
#
#  aggregation :enum             not null, primary key
#  date        :date             not null, primary key
#  field       :enum             not null, primary key
#  value       :float            not null
#
# Indexes
#
#  index_summary_values_on_field_and_aggregation_and_date  (field,aggregation,date)
#
# Foreign Keys
#
#  fk_rails_...  (date => summaries.date) ON DELETE => cascade
#
class SummaryValue < ApplicationRecord
  belongs_to :summary,
             primary_key: :date,
             foreign_key: :date,
             inverse_of: :values

  enum :field,
       {
         battery_charging_power: 'battery_charging_power',
         battery_charging_power_grid: 'battery_charging_power_grid',
         battery_discharging_power: 'battery_discharging_power',
         battery_soc: 'battery_soc',
         car_battery_soc: 'car_battery_soc',
         case_temp: 'case_temp',
         grid_export_power: 'grid_export_power',
         grid_import_power: 'grid_import_power',
         heatpump_power: 'heatpump_power',
         heatpump_power_grid: 'heatpump_power_grid',
         house_power: 'house_power',
         house_power_grid: 'house_power_grid',
         inverter_power: 'inverter_power',
         inverter_power_forecast: 'inverter_power_forecast',
         wallbox_power: 'wallbox_power',
         wallbox_power_grid: 'wallbox_power_grid',
         custom_power_01: 'custom_power_01',
         custom_power_02: 'custom_power_02',
         custom_power_03: 'custom_power_03',
         custom_power_04: 'custom_power_04',
         custom_power_05: 'custom_power_05',
         custom_power_06: 'custom_power_06',
         custom_power_07: 'custom_power_07',
         custom_power_08: 'custom_power_08',
         custom_power_09: 'custom_power_09',
         custom_power_10: 'custom_power_10',
         custom_power_11: 'custom_power_11',
         custom_power_12: 'custom_power_12',
         custom_power_13: 'custom_power_13',
         custom_power_14: 'custom_power_14',
         custom_power_15: 'custom_power_15',
         custom_power_16: 'custom_power_16',
         custom_power_17: 'custom_power_17',
         custom_power_18: 'custom_power_18',
         custom_power_19: 'custom_power_19',
         custom_power_20: 'custom_power_20',
         custom_power_01_grid: 'custom_power_01_grid',
         custom_power_02_grid: 'custom_power_02_grid',
         custom_power_03_grid: 'custom_power_03_grid',
         custom_power_04_grid: 'custom_power_04_grid',
         custom_power_05_grid: 'custom_power_05_grid',
         custom_power_06_grid: 'custom_power_06_grid',
         custom_power_07_grid: 'custom_power_07_grid',
         custom_power_08_grid: 'custom_power_08_grid',
         custom_power_09_grid: 'custom_power_09_grid',
         custom_power_10_grid: 'custom_power_10_grid',
         custom_power_11_grid: 'custom_power_11_grid',
         custom_power_12_grid: 'custom_power_12_grid',
         custom_power_13_grid: 'custom_power_13_grid',
         custom_power_14_grid: 'custom_power_14_grid',
         custom_power_15_grid: 'custom_power_15_grid',
         custom_power_16_grid: 'custom_power_16_grid',
         custom_power_17_grid: 'custom_power_17_grid',
         custom_power_18_grid: 'custom_power_18_grid',
         custom_power_19_grid: 'custom_power_19_grid',
         custom_power_20_grid: 'custom_power_20_grid',
       },
       suffix: true,
       enum_type: :field_enum

  enum :aggregation,
       { sum: 'sum', max: 'max', min: 'min', avg: 'avg' },
       suffix: true,
       enum_type: :aggregation_enum

  validates :field, :aggregation, :value, presence: true
end
