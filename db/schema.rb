# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_04_07_104842) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  # Custom types defined in this database.
  # Note that some types may not work with other database engines. Be careful if changing database.
  create_enum "aggregation_enum", ["sum", "max", "min", "avg"]
  create_enum "field_enum", ["battery_charging_power", "battery_charging_power_grid", "battery_discharging_power", "battery_soc", "car_battery_soc", "case_temp", "grid_export_power", "grid_import_power", "heatpump_power", "heatpump_power_grid", "house_power", "house_power_grid", "inverter_power", "inverter_power_forecast", "wallbox_power", "wallbox_power_grid", "custom_power_01", "custom_power_02", "custom_power_03", "custom_power_04", "custom_power_05", "custom_power_06", "custom_power_07", "custom_power_08", "custom_power_09", "custom_power_10", "custom_power_01_grid", "custom_power_02_grid", "custom_power_03_grid", "custom_power_04_grid", "custom_power_05_grid", "custom_power_06_grid", "custom_power_07_grid", "custom_power_08_grid", "custom_power_09_grid", "custom_power_10_grid", "custom_power_11", "custom_power_12", "custom_power_13", "custom_power_14", "custom_power_15", "custom_power_16", "custom_power_17", "custom_power_18", "custom_power_19", "custom_power_20", "custom_power_11_grid", "custom_power_12_grid", "custom_power_13_grid", "custom_power_14_grid", "custom_power_15_grid", "custom_power_16_grid", "custom_power_17_grid", "custom_power_18_grid", "custom_power_19_grid", "custom_power_20_grid", "inverter_power_1", "inverter_power_2", "inverter_power_3", "inverter_power_4", "inverter_power_5"]

  create_table "prices", force: :cascade do |t|
    t.string "name", null: false
    t.date "starts_at", null: false
    t.decimal "value", precision: 8, scale: 5, null: false
    t.string "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name", "starts_at"], name: "index_prices_on_name_and_starts_at", unique: true
  end

  create_table "settings", force: :cascade do |t|
    t.string "var", null: false
    t.text "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["var"], name: "index_settings_on_var", unique: true
  end

  create_table "summaries", primary_key: "date", id: :date, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["updated_at"], name: "index_summaries_on_updated_at"
  end

  create_table "summary_values", primary_key: ["date", "aggregation", "field"], force: :cascade do |t|
    t.date "date", null: false
    t.enum "field", null: false, enum_type: "field_enum"
    t.enum "aggregation", null: false, enum_type: "aggregation_enum"
    t.float "value", null: false
    t.index ["field", "aggregation", "date"], name: "index_summary_values_on_field_and_aggregation_and_date"
  end

  add_foreign_key "summary_values", "summaries", column: "date", primary_key: "date", on_delete: :cascade
end
