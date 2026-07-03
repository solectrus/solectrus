# == Schema Information
#
# Table name: cash_flows
#
#  id         :bigint           not null, primary key
#  amount     :decimal(10, 2)   not null
#  date       :date             not null
#  note       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_cash_flows_on_date  (date)
#
class CashFlow < ApplicationRecord
  validates :date, presence: true
  validates :note, presence: true
  validates :amount, presence: true, numericality: { other_than: 0 }

  scope :ordered, -> { order(date: :desc, created_at: :desc) }

  after_commit do
    broadcast_update_to 'cash_flows',
                        partial: 'settings/cash_flows/list',
                        target: 'list',
                        locals: {
                          cash_flows: CashFlow.ordered,
                        }
  end
end
