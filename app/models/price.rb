# == Schema Information
#
# Table name: prices
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  note       :string
#  starts_at  :date             not null
#  value      :decimal(8, 5)    not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_prices_on_name_and_starts_at  (name,starts_at) UNIQUE
#
class Price < ApplicationRecord
  validates :name, presence: true
  validates :starts_at, presence: true, uniqueness: { scope: :name }
  validates :value,
            presence: true,
            numericality: {
              greater_than_or_equal_to: 0,
            }

  enum :name, electricity: 'electricity', feed_in: 'feed_in'

  scope :list_for, ->(name) { where(name:).order(starts_at: :desc) }

  after_destroy :reprice_sessions
  after_save :reprice_sessions, if: -> { saved_change_to_value? || saved_change_to_starts_at? || saved_change_to_name? }

  def self.seed!
    { electricity: 0.2545, feed_in: 0.0832 }.each do |name, value|
      find_or_create_by!(name:, starts_at: Rails.configuration.x.installation_date) do |price|
        price.value = value
      end
    end
  end

  # Get the price valid for a specific date
  def self.at(name:, date:)
    Price
      .where(name:)
      .where(starts_at: ..date)
      .order(starts_at: :desc)
      .pick(:value)
  end

  private

  # A wallbox session stores its cost from the prices of its day, so the
  # sessions get a new cost on each day whose price changes (see
  # ChargingSession.reprice). These are the days from the start of the price
  # to the start of the next price of its name, before and after the change.
  def reprice_sessions
    [[name, starts_at], [name_before_last_save, starts_at_before_last_save]].uniq.each do |price_name, start|
      ChargingSession.reprice(days_of(price_name, start)) if price_name && start
    end
  end

  # The days with the price of the given name that starts on the given date
  def days_of(price_name, start)
    next_start = Price.where(name: price_name, starts_at: start.next_day..).minimum(:starts_at)
    start..next_start&.prev_day
  end
end
