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

  after_commit do |price|
    SummaryUpdater.call

    broadcast_update_to "prices_#{price.name}",
                        partial: 'settings/prices/list',
                        target: 'list',
                        locals: {
                          prices: Price.list_for(price.name),
                          name: price.name,
                        }
  end

  def self.seed!
    Price.electricity.create! starts_at:
                                Rails.configuration.x.installation_date,
                              value: 0.2545

    Price.feed_in.create! starts_at: Rails.configuration.x.installation_date,
                          value: 0.0832
  end

  def self.list_for(name)
    Price.where(name:).order(starts_at: :desc).to_a
  end

  # Don't allow deleting last price of a scope
  def destroyable?
    Price.where.not(id:).exists?(name:)
  end
end
