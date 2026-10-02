# A car of the installation. The id is the number of the car, which names its
# sensors (car_mileage_2) and its environment variables
# (INFLUX_SENSOR_CAR_MILEAGE_2). The environment stays the source of the
# sensor configuration, because Helios writes it. The table holds what the
# environment cannot: the name, the period of use and the color.
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
#  color        :string
#  name         :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
class Car < ApplicationRecord
  # The color of a car without a color of its own
  DEFAULT_COLORS = %w[#3b82f6 #f97316 #10b981 #a855f7 #ec4899].freeze
  private_constant :DEFAULT_COLORS

  COLOR_FORMAT = /\A#\h{6}\z/
  private_constant :COLOR_FORMAT

  NAMES_CACHE_KEY = 'cars/names'.freeze
  private_constant :NAMES_CACHE_KEY

  # The first day of use, the installation date unless the user knows better
  attribute :active_from, default: -> { Rails.configuration.x.installation_date }

  has_many :charging_sessions, dependent: :restrict_with_error

  normalizes :name, with: -> { it.strip.presence }
  normalizes :color, with: -> { it.strip.downcase.presence }

  validates :id, inclusion: { in: Sensor::Cars.numbers }
  validates :active_from, presence: true
  validates :color, format: { with: COLOR_FORMAT }, allow_nil: true
  validate :period_in_order
  validate :offsite_sessions_in_period, if: -> { will_save_change_to_active_from? || will_save_change_to_active_until? }

  after_save :reset_detection, if: -> { saved_change_to_active_from? || saved_change_to_active_until? }
  after_commit :clear_names

  # The id is the order of the cars
  scope :ordered, -> { order(:id) } # rubocop:disable Rails/OrderById

  # { id => name } of the cars with a name. Without the table, because a
  # migration has not run yet, there is no name.
  def self.names
    Current.car_names ||=
      if table_exists?
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

  def self.default_color(id)
    DEFAULT_COLORS[(id - 1) % DEFAULT_COLORS.size]
  end

  def display_name = self.class.display_name_of(id)

  def display_color = color || self.class.default_color(id)

  # The days of use, from the first day of use to the last day of use or
  # today
  def period(today: Date.current)
    active_from..(active_until || today)
  end

  def active_on?(date)
    active_from <= date && (active_until.nil? || active_until >= date)
  end

  private

  def period_in_order
    return unless active_from && active_until && active_until < active_from

    errors.add(:active_until, :before_active_from)
  end

  # An offsite session has no detection, so nothing could take its car away
  # again. The period must therefore hold each offsite session of the car.
  def offsite_sessions_in_period
    return if new_record? || active_from.nil?

    outside = charging_sessions.offsite.where.not(started_at: period_times).count
    return if outside.zero?

    errors.add(:base, :offsite_sessions_outside, count: outside)
  end

  # The period as times, from the local start of its first day to the local
  # end of its last day, without an end for a car in use
  def period_times
    active_from.beginning_of_day..active_until&.end_of_day
  end

  # The candidates of a wallbox session change on the days between the old and
  # the new bound. A session of this car outside the new period loses the car
  # at once, and the next build runs the detection on these days again (see
  # ChargingSession::Detection).
  def reset_detection
    days = changed_days
    return if days.empty?

    charging_sessions
      .wallbox
      .where.not(started_at: period_times)
      .update_all(car_id: nil) # rubocop:disable Rails/SkipsModelValidations

    Summary.where(date: days).update_all(charging_sessions_version: nil) # rubocop:disable Rails/SkipsModelValidations
  end

  # The days between the old and the new value of each bound. A missing
  # bound reaches the installation date (a new car) or today (no last day).
  def changed_days
    from_before, from_after = saved_change_to_active_from || [active_from, active_from]
    until_before, until_after = saved_change_to_active_until || [active_until, active_until]

    [
      bound_range(from_before, from_after, Rails.configuration.x.installation_date),
      bound_range(until_before, until_after, Date.current),
    ].compact
  end

  def bound_range(before, after, open_end)
    return if before == after

    dates = [before || open_end, after || open_end]
    dates.min..dates.max
  end

  def clear_names
    Rails.cache.delete(NAMES_CACHE_KEY)
    Current.car_names = nil
  end
end
