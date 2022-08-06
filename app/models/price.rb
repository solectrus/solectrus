class Price < ApplicationRecord
  validates :name, presence: true
  validates :starts_at, presence: true, uniqueness: { scope: :name }
  validates :value, presence: true, numericality: { greater_than: 0 }

  enum :name, electricity: 'electricity', feed_in: 'feed_in'

  # Don't allow deleting last price of a scope
  def destroyable?
    Price.where.not(id:).exists?(name:)
  end

  def self.seed!
    Price.electricity.create! starts_at:
                                Rails.configuration.x.installation_date,
                              value: Rails.configuration.x.electricity_price

    Price.feed_in.create! starts_at: Rails.configuration.x.installation_date,
                          value: Rails.configuration.x.feed_in_tariff
  end
end
