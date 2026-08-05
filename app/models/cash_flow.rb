# == Schema Information
#
# Table name: cash_flows
#
#  id         :bigint           not null, primary key
#  amount     :decimal(10, 2)   not null
#  category   :string           not null
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
  # Business classification of a cash flow. The category - not the sign alone -
  # decides how the amount enters the amortization calculation (see
  # AmortizationCalculator): the investment base, the operating cash flow, or
  # nothing. This keeps a subsidy/refund from being counted as operating payback.
  enum :category,
       {
         investment: 'investment',
         subsidy: 'subsidy',
         refund: 'refund',
         operating_cost: 'operating_cost',
         repair: 'repair',
         compensation: 'compensation',
         manual_savings: 'manual_savings',
         other: 'other',
       },
       validate: true

  # Categories that must be an outflow (negative amount) resp. an inflow
  # (positive amount); 'other' is unconstrained (neutral, either sign).
  OUTFLOW_CATEGORIES = %w[investment operating_cost repair].freeze
  public_constant :OUTFLOW_CATEGORIES

  INFLOW_CATEGORIES = %w[subsidy refund compensation manual_savings].freeze
  public_constant :INFLOW_CATEGORIES

  # Categories that shape the (net) investment base: investment raises it,
  # subsidy/refund lower it. Their signed sum, negated, is the net investment.
  INVESTMENT_BASE_CATEGORIES = %w[investment subsidy refund].freeze
  public_constant :INVESTMENT_BASE_CATEGORIES

  # Categories that flow into the operating cash flow (alongside the measured
  # savings): compensation/manual_savings add, operating_cost/repair subtract.
  #
  # manual_savings covers periods the sensors never saw - typically the years
  # before SOLECTRUS was installed, but also gaps from an outage or a migration.
  # It adds up with the measured savings without overlapping them as long as it
  # stays in those periods: the measured series starts at the first day with data
  # (see AmortizationCalculator::SavingsSeries) and contributes nothing for days
  # without a summary. Nothing enforces that, though - an entry dated inside the
  # measured range does get counted twice.
  OPERATING_CATEGORIES = %w[
    compensation
    manual_savings
    operating_cost
    repair
  ].freeze
  public_constant :OPERATING_CATEGORIES

  validates :date, presence: true
  validates :note, presence: true
  validates :amount, presence: true, numericality: { other_than: 0 }
  validate :amount_matches_category_sign

  # Fall back to a sign-based category when none is given, so records created
  # without one (older callers, the migration's semantics) stay consistent with
  # the strict sign validation below.
  before_validation :infer_category_from_sign,
                    if: -> { category.blank? && amount.present? }

  scope :ordered, -> { order(date: :desc, created_at: :desc) }

  private

  def infer_category_from_sign
    self.category = amount.negative? ? :investment : :compensation
  end

  def amount_matches_category_sign
    return if amount.blank? || category.blank?

    if OUTFLOW_CATEGORIES.include?(category) && !amount.negative?
      errors.add(:amount, :must_be_negative)
    elsif INFLOW_CATEGORIES.include?(category) && !amount.positive?
      errors.add(:amount, :must_be_positive)
    end
  end
end
