# The cars, their numbered daily values and the charging sessions
# (docs/cars.md). It starts from the database of v1.3, which has
# car_battery_soc as its only car record.
class AddCars < ActiveRecord::Migration[8.1]
  # Sensor::Cars::MAX, repeated here because a migration must not change
  # with the application code
  NUMBERS = (1..5)
  private_constant :NUMBERS

  class MigrationCar < ActiveRecord::Base
    self.table_name = 'cars'
  end
  private_constant :MigrationCar

  def up
    add_field_labels
    create_cars
    create_charging_sessions

    # NULL marks each existing day as pending for the detection of the
    # charging sessions
    add_column :summaries, :charging_sessions_version, :integer

    move_car_name
  end

  def down
    name = MigrationCar.find_by(id: 1)&.name
    Setting.sensor_names = Setting.sensor_names.merge('car_battery_soc' => name) if name

    remove_column :summaries, :charging_sessions_version
    drop_table :charging_sessions
    drop_table :cars

    # PostgreSQL has no DROP VALUE, so the new labels stay
    rename_enum_value :field_enum, from: 'car_battery_soc_1', to: 'car_battery_soc'
  end

  private

  # car_battery_soc is in a release, so its rows keep their data under the
  # number of the first car. A rename changes the type alone, no row. No row
  # uses a new label in this transaction, which PostgreSQL would refuse.
  def add_field_labels
    if enum_value?(:field_enum, 'car_battery_soc')
      rename_enum_value :field_enum, from: 'car_battery_soc', to: 'car_battery_soc_1'
    end

    %w[car_battery_soc car_mileage car_max_range car_range].each do |field|
      NUMBERS.each do |number|
        add_enum_value :field_enum, :"#{field}_#{number}", if_not_exists: true
      end
    end
  end

  # The id is the number of the car, which the user enters, so it has no
  # sequence
  def create_cars
    create_table :cars, id: :integer, default: nil do |t|
      t.string :name
      t.date :active_from, null: false
      t.date :active_until
      t.string :color

      t.timestamps

      t.check_constraint 'active_until IS NULL OR active_until >= active_from', name: 'cars_period_order'
    end
  end

  def create_charging_sessions
    create_table :charging_sessions do |t|
      t.string :kind, null: false
      t.references :car, type: :integer, foreign_key: { name: 'charging_sessions_car_id_fkey' }, index: false
      t.boolean :guest, null: false, default: false
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.decimal :kwh, precision: 10, scale: 3, null: false
      t.decimal :kwh_grid, precision: 10, scale: 3
      t.decimal :cost, precision: 10, scale: 2
      t.decimal :cost_grid, precision: 10, scale: 2
      t.string :evse_id
      t.string :power_type
      t.string :provider
      t.string :address
      t.text :note

      t.timestamps

      # The rules between the columns, because the detection writes with an
      # upsert, which skips the validations of the model. The lists of values
      # stay in the model, so that they can grow without a migration. No check
      # on the cost, because a dynamic price can be negative.
      t.check_constraint "NOT guest OR (kind = 'wallbox' AND car_id IS NULL)",
                         name: 'charging_sessions_guest'
      t.check_constraint "kind <> 'offsite' OR car_id IS NOT NULL",
                         name: 'charging_sessions_offsite_car'
      t.check_constraint "kind <> 'wallbox' OR ended_at IS NOT NULL",
                         name: 'charging_sessions_wallbox_end'
      t.check_constraint 'kwh > 0', name: 'charging_sessions_kwh'
      t.check_constraint 'kwh_grid IS NULL OR kwh_grid BETWEEN 0 AND kwh',
                         name: 'charging_sessions_kwh_grid'
      t.check_constraint 'ended_at IS NULL OR ended_at >= started_at',
                         name: 'charging_sessions_period_order'
    end

    add_index :charging_sessions, %i[car_id started_at]
    add_index :charging_sessions, %i[kind started_at]

    # The detection writes with an upsert on the start of a session
    add_index :charging_sessions,
              :started_at,
              unique: true,
              where: "kind = 'wallbox'",
              name: 'index_charging_sessions_on_wallbox_start'
  end

  # The car management page holds the names of the cars now. The first car
  # gets the name also without a variable, because a car without a
  # configuration stays hidden (see Car::Provisioning).
  def move_car_name
    names = Setting.sensor_names
    return unless names.key?('car_battery_soc')

    name = names['car_battery_soc'].presence
    MigrationCar.create!(id: 1, name:, active_from: Rails.configuration.x.installation_date) if name

    Setting.sensor_names = names.except('car_battery_soc')
  end

  def enum_value?(type, value)
    select_value(<<~SQL.squish, 'SQL', [type.to_s, value]).present?
      SELECT 1 FROM pg_enum
      JOIN pg_type ON pg_type.oid = pg_enum.enumtypid
      WHERE pg_type.typname = $1 AND pg_enum.enumlabel = $2
    SQL
  end
end
