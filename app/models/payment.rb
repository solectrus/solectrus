# A payment on a date, for example the purchase of a car or the maintenance
# of the heat pump. The payments of the cars and of the heat pump share one
# table, and the class of each payment names what it belongs to (see
# Car::Payment and Heatpump::Payment).
#
# The category gives the direction: an income or an expense. Each class
# names its categories as EXPENSES and INCOMES, in the order of its form.
# The amount of an expense can be negative: a refund lowers the cost of its
# category. A payment does not count in the amortization, because it is no
# part of the PV system.
# == Schema Information
#
# Table name: payments
#
#  id         :bigint           not null, primary key
#  amount     :decimal(10, 2)   not null
#  category   :string           not null
#  date       :date             not null
#  note       :string
#  type       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  car_id     :integer
#
# Indexes
#
#  index_payments_on_car_id         (car_id)
#  index_payments_on_type_and_date  (type,date)
#
# Foreign Keys
#
#  fk_rails_...  (car_id => cars.id)
#
class Payment < ApplicationRecord
  scope :ordered, -> { order(date: :desc, id: :desc) }

  # The sum of the payments, positive for more income than expense. One
  # query adds the incomes and subtracts the expenses.
  def self.signed_sum
    amount = arel_table[:amount]
    sum(Arel::Nodes::Case.new.when(arel_table[:category].in(self::INCOMES)).then(amount).else(Arel::Nodes::UnaryOperation.new('-', amount)))
  end

  def self.income?(category) = category.in?(self::INCOMES)

  normalizes :note, with: -> { it.strip.presence }

  validates :date, presence: true
  validates :amount, presence: true, numericality: { other_than: 0, greater_than: -100_000_000, less_than: 100_000_000 }
  validates :amount, numericality: { greater_than: 0 }, if: :income?

  def income? = self.class.income?(category)

  # The amount with the sign of its category: an income is positive, an
  # expense negative
  def signed_amount = income? ? amount : -amount
end
