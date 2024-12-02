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

ActiveRecord::Schema[7.2].define(version: 2024_10_27_112350) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

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
    t.float "sum_inverter_power"
    t.float "sum_inverter_power_forecast"
    t.float "sum_house_power"
    t.float "sum_heatpump_power"
    t.float "sum_grid_import_power"
    t.float "sum_grid_export_power"
    t.float "sum_battery_charging_power"
    t.float "sum_battery_discharging_power"
    t.float "sum_wallbox_power"
    t.float "max_inverter_power"
    t.float "max_house_power"
    t.float "max_heatpump_power"
    t.float "max_grid_import_power"
    t.float "max_grid_export_power"
    t.float "max_battery_charging_power"
    t.float "max_battery_discharging_power"
    t.float "max_wallbox_power"
    t.float "min_battery_soc"
    t.float "min_car_battery_soc"
    t.float "min_case_temp"
    t.float "max_battery_soc"
    t.float "max_car_battery_soc"
    t.float "max_case_temp"
    t.float "avg_battery_soc"
    t.float "avg_car_battery_soc"
    t.float "avg_case_temp"
    t.float "sum_house_power_grid"
    t.float "sum_wallbox_power_grid"
    t.float "sum_heatpump_power_grid"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.float "sum_heatpump_heating_power"
    t.float "max_heatpump_heating_power"
    t.float "avg_heatpump_score"
    t.float "min_outdoor_temp"
    t.float "max_outdoor_temp"
    t.float "avg_outdoor_temp"
    t.float "car_driving_distance"
    t.float "sum_custom_01_power"
    t.float "sum_custom_02_power"
    t.float "sum_custom_03_power"
    t.float "sum_custom_04_power"
    t.float "sum_custom_05_power"
    t.float "sum_custom_06_power"
    t.float "sum_custom_07_power"
    t.float "sum_custom_08_power"
    t.float "sum_custom_09_power"
    t.float "sum_custom_10_power"
    t.index ["updated_at"], name: "index_summaries_on_updated_at"
  end
end
