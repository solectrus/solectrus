# A payment of the heat pump on a date, for example its purchase, its
# maintenance or a subsidy (see Payment).
#
# The comparison with a fossil heating (see Heatpump::Comparison) counts
# the running costs for the heat pump (see COMPARED).
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
class Heatpump::Payment < Payment
  # The expenses first, then the incomes, in the order of the form
  EXPENSES = %w[purchase maintenance operating_costs other_expense].freeze
  public_constant :EXPENSES

  INCOMES = %w[subsidy].freeze
  public_constant :INCOMES

  # The categories that the comparison with a fossil heating counts: the
  # running costs of the heat pump. They count for the heat pump alone,
  # because the fossil heating has running costs of its own (see
  # Heatpump::Heating). The purchase, with the installation, the accessories
  # and the rates of a loan for them, and a subsidy are the investment and no
  # running costs. They stay out, because a fossil heating has another price.
  COMPARED = %w[maintenance operating_costs other_expense].freeze
  public_constant :COMPARED

  # A new payment has no category, so the form asks for one
  enum :category, (EXPENSES + INCOMES).index_with(&:itself), validate: true

  scope :compared, -> { where(category: COMPARED) }
end
