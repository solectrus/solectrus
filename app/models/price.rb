# == Schema Information
#
# Table name: prices
#
#  id               :bigint           not null, primary key
#  amount_per_month :decimal(8, 2)
#  name             :string           not null
#  note             :string
#  starts_at        :date             not null
#  value            :decimal(8, 5)    not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_prices_on_name_and_starts_at  (name,starts_at) UNIQUE
#
class Price < ApplicationRecord
  # The database column is still called `value`. Renaming it would break older
  # SOLECTRUS versions that a user can roll back to, so the rename waits for a
  # release that no longer needs to be compatible with them.
  alias_attribute :amount_per_kwh, :value

  validates :name, presence: true
  validates :starts_at, presence: true, uniqueness: { scope: :name }
  validates :amount_per_kwh,
            presence: true,
            numericality: {
              greater_than_or_equal_to: 0,
            }
  # A base fee belongs to the grid connection, so only the electricity tariff
  # can carry one.
  validates :amount_per_month,
            numericality: {
              greater_than_or_equal_to: 0,
              allow_nil: true,
            },
            absence: {
              unless: :electricity?,
            }

  enum :name, electricity: 'electricity', feed_in: 'feed_in'

  scope :list_for, ->(name) { where(name:).order(starts_at: :desc) }

  # The records in force on a date, newest first: the first one is the one that
  # applies.
  scope :in_force_on,
        ->(date) { where(starts_at: ..date).order(starts_at: :desc) }

  def self.seed!
    { electricity: 0.2545, feed_in: 0.0832 }.each do |name, amount|
      find_or_create_by!(name:, starts_at: Rails.configuration.x.installation_date) do |price|
        price.amount_per_kwh = amount
      end
    end
  end

  # A tariff always keeps at least one price, so its last one cannot go.
  def destroyable?
    persisted? && Price.where(name:).many?
  end

  # Get the price valid for a specific date
  def self.at(name:, date:)
    where(name:).in_force_on(date).pick(:amount_per_kwh)
  end
end
