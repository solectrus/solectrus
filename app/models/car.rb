# A car of the installation (docs/cars.md). The id is the number of the car,
# which names its sensors (car_odometer_2) and its environment variables
# (INFLUX_SENSOR_CAR_ODOMETER_2). The environment stays the source of the
# sensor configuration, because Helios writes it. The table holds what the
# environment cannot: the name, the short name, the period of use, the
# color and the usable capacity of the battery.
#
# The number of a car never changes, because the daily values store its
# history under the sensor name with the number. SOLECTRUS never removes a
# car, so a sold car keeps its number and its history.
# == Schema Information
#
# Table name: cars
#
#  id           :integer          not null, primary key
#  active_from  :date             not null
#  active_until :date
#  battery_kwh  :decimal(5, 1)
#  color        :string
#  name         :string
#  short_name   :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
class Car < ApplicationRecord
  # The color of a car without a color of its own
  DEFAULT_COLOR = '#6366f1'.freeze # indigo-500
  public_constant :DEFAULT_COLOR

  COLOR_FORMAT = /\A#\h{6}\z/
  private_constant :COLOR_FORMAT

  # The short name stands where the full name takes too much space, for
  # example on the button of the car select in the page header
  SHORT_NAME_MAX = 5
  public_constant :SHORT_NAME_MAX

  NAMES_CACHE_KEY = 'cars/names'.freeze
  private_constant :NAMES_CACHE_KEY

  # The first day of use, the installation date unless the user knows better
  attribute :active_from, default: -> { Rails.configuration.x.installation_date }

  has_many :charging_sessions, dependent: :restrict_with_error
  has_many :place_visits, dependent: :delete_all

  normalizes :name, :short_name, with: -> { it.strip.presence }
  normalizes :color, with: -> { it.strip.downcase.presence }

  validates :id, inclusion: { in: Sensor::Cars.numbers }
  validates :short_name, presence: true, length: { maximum: SHORT_NAME_MAX }
  validates :active_from, presence: true
  validates :color, format: { with: COLOR_FORMAT }, allow_nil: true
  validates :battery_kwh, numericality: { greater_than: 0, less_than: 10_000 }, allow_nil: true
  validate :period_in_order
  validate :offsite_sessions_in_period, if: -> { will_save_change_to_active_from? || will_save_change_to_active_until? }

  # A new car takes its number as short name, until the user gives it one
  before_validation -> { self.short_name ||= id&.to_s }, on: :create
  after_save -> { Car::PeriodChange.new(self).call }, if: -> { saved_change_to_active_from? || saved_change_to_active_until? }
  after_save -> { ChargingSession.reestimate(self) }, if: :saved_change_to_battery_kwh?
  after_commit :clear_current

  # The id is the order of the cars
  scope :ordered, -> { order(:id) } # rubocop:disable Rails/OrderById

  # The cars of the configured numbers, ordered by number. A configured
  # number without a car gets one, so a user with one car has nothing to
  # do. Two parallel requests make one record, because the insert ignores
  # an existing id.
  #
  # It runs on the first request that needs a car and not in
  # Sensor::Config, because a database write at configuration time couples
  # the two layers. A request reads the cars one time (see Current). Without
  # the table, because a migration has not run yet, there is no car.
  def self.configured
    Current.cars ||=
      if table_exists?
        numbers = Sensor::Cars.configured_numbers
        cars = where(id: numbers).ordered.to_a
        missing = numbers - cars.map(&:id)
        if missing.any?
          insert_all(missing.map { { id: it, short_name: it.to_s, active_from: Rails.configuration.x.installation_date } }, unique_by: :id) # rubocop:disable Rails/SkipsModelValidations
          cars = where(id: numbers).ordered.to_a
        end

        cars.freeze
      else
        [].freeze
      end
  end

  # The configured car of an id in the address
  def self.find_configured!(id)
    configured.find { it.id.to_s == id.to_s } || raise(ActiveRecord::RecordNotFound)
  end

  # { id => name } of the cars with a name. Without the table there is no
  # name, and a guest gets none (see Current.car_names_hidden).
  def self.names
    Current.car_names ||=
      if table_exists? && !Current.car_names_hidden
        Rails.cache.fetch(NAMES_CACHE_KEY) { where.not(name: nil).pluck(:id, :name).to_h }
      else
        {}
      end
  end

  def self.name_of(id) = names[id]

  # The name of the car, or the default name of its id
  def self.display_name_of(id)
    name_of(id) || I18n.t('cars.default_name', number: id)
  end

  def display_name = self.class.display_name_of(id)

  # A guest sees the default name of the car: "Car 1"
  def short_name = Current.car_names_hidden ? display_name : super

  def display_color = color || DEFAULT_COLOR

  # The sensor of this car with the given role: car_odometer_2
  def sensor_name(role) = Sensor::Cars.sensor_name(role, id)

  def sensor?(role) = Sensor::Config.exists?(sensor_name(role))

  def located? = Sensor::Cars.located?(id)

  def active_on?(date)
    active_during?(date..date)
  end

  # Whether the period of use holds a day of the given dates
  def active_during?(dates)
    active_from <= dates.last && (active_until.nil? || active_until >= dates.first)
  end

  # The period as times, from the local start of its first day to the local
  # end of its last day, without an end for a car in use
  def period_times
    active_from.beginning_of_day..active_until&.end_of_day
  end

  private

  def period_in_order
    return unless active_from && active_until && active_until < active_from

    errors.add(:active_until, :before_active_from)
  end

  # An offsite session of the user has no detection, so nothing could take
  # its car away again. The period must therefore hold each such session of
  # the car. A proposal outside goes (see Car::PeriodChange).
  def offsite_sessions_in_period
    return if new_record? || active_from.nil?

    outside = charging_sessions.offsite.effective.where.not(started_at: period_times).count
    return if outside.zero?

    errors.add(:base, :offsite_sessions_outside, count: outside)
  end

  def clear_current
    Rails.cache.delete(NAMES_CACHE_KEY)
    Current.car_names = nil
    Current.cars = nil
  end
end
