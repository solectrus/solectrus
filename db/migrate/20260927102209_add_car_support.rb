# The cars, their numbered daily values, the charging sessions, the places
# with the visits of the cars and the versions of the steps of the daily
# build (docs/cars.md). It starts from the database of v1.3, which has
# car_battery_soc as its only car record.
class AddCarSupport < ActiveRecord::Migration[8.1]
  # Sensor::Cars::MAX, repeated here because a migration must not change
  # with the application code
  NUMBERS = (1..5)
  private_constant :NUMBERS

  class MigrationCar < ActiveRecord::Base
    self.table_name = 'cars'
  end
  private_constant :MigrationCar

  # The settings without the class Setting, which can change with the
  # application code. rails-settings-cached stores a value as YAML and keeps
  # all values in Rails.cache, so a write clears the cache.
  class MigrationSetting < ActiveRecord::Base
    self.table_name = 'settings'

    def self.read(var)
      value = find_by(var:)&.value
      YAML.unsafe_load(value) if value.present?
    end

    def self.write(var, value)
      find_or_initialize_by(var:).update!(value: value.to_yaml)
      Rails.cache.clear
    end
  end
  private_constant :MigrationSetting

  def up
    add_field_enum_values
    create_cars
    create_charging_sessions
    create_places

    # The version of each step of the daily build that ran on a day (see
    # Summary::Steps). An empty object marks each existing day as pending
    # for each step.
    add_column :summaries, :steps, :jsonb, null: false, default: {}

    move_car_name
  end

  def down
    name = MigrationCar.find_by(id: 1)&.name
    if name
      names = MigrationSetting.read('sensor_names') || {}
      MigrationSetting.write('sensor_names', names.merge('car_battery_soc' => name))
    end

    remove_column :summaries, :steps
    drop_table :place_visits
    drop_table :places
    drop_table :charging_sessions
    drop_table :cars

    # PostgreSQL has no DROP VALUE, so the new enum values stay
  end

  private

  # car_battery_soc stays as it is, so that an older version of the
  # application still runs on the database. The daily values of the first car
  # come from the next build: each day waits for the new steps, and a day with
  # a waiting step is built again in full (see Sensor::Summarizer).
  def add_field_enum_values
    %w[car_battery_soc car_odometer car_max_range car_range].each do |field|
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
      t.string :short_name, null: false
      t.date :active_from, null: false
      t.date :active_until
      t.string :color
      # The usable capacity of the battery, for the estimate of an offsite
      # session and the loss of a charge
      t.decimal :battery_kwh, precision: 5, scale: 1

      t.timestamps

      t.check_constraint 'active_until IS NULL OR active_until >= active_from', name: 'cars_period_order'
      t.check_constraint 'battery_kwh IS NULL OR battery_kwh > 0', name: 'cars_battery_kwh'
    end
  end

  def create_charging_sessions
    create_table :charging_sessions do |t|
      # Where the energy flowed: at the wallbox or offsite
      t.string :kind, null: false
      # Who made the row: the detection or the user
      t.string :origin, null: false
      t.references :car, type: :integer, foreign_key: { name: 'charging_sessions_car_id_fkey' }, index: false
      t.boolean :guest, null: false, default: false
      # Whether the user chose the car, the guest mark or "not assigned". A
      # new build of the detection keeps such a choice.
      t.boolean :assigned_manually, null: false, default: false
      t.datetime :started_at, null: false
      t.datetime :ended_at
      # A proposal of an offsite session can be without energy
      t.decimal :kwh, precision: 10, scale: 3
      t.decimal :kwh_grid, precision: 10, scale: 3
      t.decimal :cost, precision: 10, scale: 2
      t.decimal :cost_grid, precision: 10, scale: 2
      t.string :evse_id
      t.string :power_type
      t.string :provider
      t.string :address
      t.text :note
      # A proposal of an offsite session that the user dismissed. Its row
      # stays, so the next build does not make it again.
      t.boolean :dismissed, null: false, default: false
      # The state of charge of the car at the start and at the end
      t.decimal :soc_from, :soc_to, precision: 4, scale: 1
      # The position of a proposal of an offsite session
      t.float :latitude, :longitude

      t.timestamps

      # The rules between the columns, because the detection writes with an
      # upsert, which skips the validations of the model. The lists of values
      # stay in the model, so that they can grow without a migration. No check
      # on the cost, because a dynamic price can be negative.
      t.check_constraint "NOT guest OR (kind = 'wallbox' AND car_id IS NULL)",
                         name: 'charging_sessions_guest'
      t.check_constraint "kind <> 'offsite' OR car_id IS NOT NULL",
                         name: 'charging_sessions_offsite_car'
      # The detection makes no guest. An offsite session without the mark
      # is a proposal of the build.
      t.check_constraint 'assigned_manually OR NOT guest',
                         name: 'charging_sessions_assigned_manually'
      t.check_constraint "NOT dismissed OR (kind = 'offsite' AND assigned_manually)",
                         name: 'charging_sessions_dismissed'
      # The user enters only offsite sessions
      t.check_constraint "origin <> 'user' OR (kind = 'offsite' AND assigned_manually)",
                         name: 'charging_sessions_user'
      t.check_constraint "kind <> 'wallbox' OR ended_at IS NOT NULL",
                         name: 'charging_sessions_wallbox_end'
      t.check_constraint 'kwh > 0', name: 'charging_sessions_kwh'
      t.check_constraint "kwh IS NOT NULL OR (kind = 'offsite' AND (NOT assigned_manually OR dismissed))",
                         name: 'charging_sessions_kwh_present'
      t.check_constraint '(soc_from IS NULL OR soc_from BETWEEN 0 AND 100) AND (soc_to IS NULL OR soc_to BETWEEN 0 AND 100)',
                         name: 'charging_sessions_soc'
      t.check_constraint 'kwh_grid IS NULL OR kwh_grid BETWEEN 0 AND kwh',
                         name: 'charging_sessions_kwh_grid'
      t.check_constraint 'ended_at IS NULL OR ended_at >= started_at',
                         name: 'charging_sessions_period_order'
    end

    add_index :charging_sessions, %i[car_id started_at]
    add_index :charging_sessions, %i[kind started_at]

    # The detection writes its own rows with an upsert on the start of a
    # session
    add_index :charging_sessions,
              :started_at,
              unique: true,
              where: "kind = 'wallbox' AND origin = 'detection'",
              name: 'index_charging_sessions_on_wallbox_start'
  end

  # The places where the cars stood, and the visits of the cars at the
  # places. The user can give a place a name of its own and labels, and the
  # address comes from Nominatim on request. A place keeps the full answer
  # of Nominatim. The code holds the list of the labels (Place::LABELS), so a
  # new label needs no migration. Only one place can be home. The daily build
  # writes the visits (see Place::VisitDetection). A visit over midnight has
  # a row for each day, so a day can be built again on its own.
  def create_places
    create_table :places do |t|
      t.float :latitude, null: false
      t.float :longitude, null: false
      t.string :name
      t.jsonb :geocoding
      t.datetime :geocoded_at
      t.string :labels, array: true, default: [], null: false

      t.timestamps

      t.index '(1)', unique: true, where: "'home' = ANY(labels)", name: 'index_places_on_home'
    end

    # The build writes the visits again and again, so a timestamp tells nothing
    create_table :place_visits do |t| # rubocop:disable Rails/CreateTableWithTimestamps
      t.date :date, null: false, index: true
      t.references :car, null: false, foreign_key: true, type: :integer, index: false
      t.references :place, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.datetime :started_at, null: false
      t.datetime :ended_at, null: false
      t.virtual :seconds, type: :integer, as: 'EXTRACT(EPOCH FROM ended_at - started_at)::integer', stored: true

      t.index %i[car_id started_at], unique: true
      t.index %i[place_id started_at]
    end
  end

  # The car management page holds the names of the cars now. The first car
  # gets the name also without a variable, because a car without a
  # configuration stays hidden (see Car.configured).
  def move_car_name
    names = MigrationSetting.read('sensor_names')
    key = key_of(names, 'car_battery_soc')
    return unless key

    name = names[key].presence
    MigrationCar.create!(id: 1, name:, short_name: '1', active_from: Rails.configuration.x.installation_date) if name

    MigrationSetting.write('sensor_names', names.except(key))
  end

  # The key of a hash with the given name, as a string or as a symbol
  def key_of(hash, name)
    hash.keys.find { it.to_s == name } if hash.is_a?(Hash)
  end
end
