class Price < ApplicationRecord
  validates :name, presence: true
  validates :starts_at, presence: true, uniqueness: { scope: :name }
  validates :value, presence: true, numericality: { greater_than: 0 }

  enum :name, electricity: 'electricity', feed_in: 'feed_in'

  after_commit ->(price) {
                 broadcast_update_to "prices_#{price.name}",
                                     partial: 'prices/list',
                                     target: 'list',
                                     locals: {
                                       prices: Price.list_for(price.name),
                                       name: price.name,
                                     }
               }

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

  def self.list_for(name)
    Price.where(name:).order(starts_at: :desc).to_a
  end
end
