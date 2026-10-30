# A payment of a car on a date, for example its purchase, a rate of its
# lease, its insurance or the GHG quota of a year. Its category gives the direction: an income or an
# expense. The amount of an expense can be negative: a refund, for example
# of the insurance, lowers the cost of its category. A payment does not
# count in the amortization, because the car is not part of the PV system.
#
# The comparison with a combustion car (see Car::Comparison) counts the
# categories of an electric car alone and the running costs (see COMPARED).
# == Schema Information
#
# Table name: car_payments
#
#  id         :bigint           not null, primary key
#  amount     :decimal(10, 2)   not null
#  category   :string           not null
#  date       :date             not null
#  note       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  car_id     :integer          not null
#
# Indexes
#
#  index_car_payments_on_car_id  (car_id)
#
# Foreign Keys
#
#  fk_rails_...  (car_id => cars.id)
#
class Car::Payment < ApplicationRecord
  belongs_to :car, inverse_of: :payments

  # The expenses first, then the incomes, in the order of the form
  EXPENSES = %w[
    purchase
    leasing_down_payment
    leasing_rate
    loan_rate
    vehicle_tax
    insurance
    maintenance
    charging_fees
    other_expense
  ].freeze
  public_constant :EXPENSES

  INCOMES = %w[subsidy ghg_quota sale].freeze
  public_constant :INCOMES

  # The categories that the comparison with a combustion car counts. The
  # categories of an electric car alone change its cost alone: the GHG
  # quota, its vehicle tax and the fees of its charging tariffs. The running
  # costs count for the combustion car too, at the same amount, so they
  # change no saving. The purchase, its financing, a subsidy and the sale
  # stay out, because a combustion car has another price.
  ELECTRIC = %w[ghg_quota charging_fees vehicle_tax].freeze
  public_constant :ELECTRIC

  SHARED = %w[insurance maintenance other_expense].freeze
  public_constant :SHARED

  COMPARED = (ELECTRIC + SHARED).freeze
  public_constant :COMPARED

  # The categories of buying and selling the car. Their date can lie outside
  # the period of use: the car and the down payment of a lease are paid
  # before it comes, and a subsidy or the sale comes after. A rate of a
  # lease or a loan falls in the period of use.
  ONE_OFF = %w[purchase leasing_down_payment subsidy sale].freeze
  public_constant :ONE_OFF

  # A new payment has no category, so the form asks for one
  enum :category, (EXPENSES + INCOMES).index_with(&:itself), validate: true

  scope :compared, -> { where(category: COMPARED) }
  scope :ordered, -> { order(date: :desc, id: :desc) }

  # The sum of the payments, positive for more income than expense. One
  # query adds the incomes and subtracts the expenses.
  def self.signed_sum
    amount = arel_table[:amount]
    sum(Arel::Nodes::Case.new.when(arel_table[:category].in(INCOMES)).then(amount).else(Arel::Nodes::UnaryOperation.new('-', amount)))
  end

  normalizes :note, with: -> { it.strip.presence }

  # The list and the comparison show the configured cars only, so a payment
  # of another car could not be found again
  validates :car_id, inclusion: { in: ->(_) { Car.configured.map(&:id) } }, if: :car_id_changed?
  validates :date, presence: true
  validates :amount, presence: true, numericality: { other_than: 0, greater_than: -100_000_000, less_than: 100_000_000 }
  validates :amount, numericality: { greater_than: 0 }, if: :income?
  validate :car_active, if: -> { car && date && category && changed.intersect?(%w[car_id date category]) }

  def self.income?(category) = category.in?(INCOMES)

  def income? = self.class.income?(category)

  # The amount with the sign of its category: an income is positive, an
  # expense negative
  def signed_amount = income? ? amount : -amount

  private

  # A payment falls in the period of use of its car, like a charging
  # session, so a payment of another car stands out. Buying and selling can
  # lie outside.
  def car_active
    return if category.in?(ONE_OFF) || car.active_on?(date)

    errors.add(:date, :inactive)
  end
end
