# The amounts of the comparison of the heat pump with a fossil heating (see
# Heatpump::Comparison) as the page shows them: each amount rounded to the
# decimals of the page (see #precision), and each sum of the rounded parts.
# So each column of the page adds up, and the badge on the heat pump page
# shows the same savings. Like Car::ComparisonAmounts.
class Heatpump::ComparisonAmounts
  def initialize(comparison)
    @comparison = comparison
  end

  # The decimals of the amounts: those of the highest cost, so a short
  # timeframe has cents and a longer one whole units
  def precision
    @precision ||= Sensor::ValueFormatter.new([comparison.total_cost, comparison.total_cost_without_pv, comparison.heating_cost].max_by(&:abs), unit: :money).precision
  end

  # The energy costs of the heat pump, with and without the PV system
  def energy_cost = comparison.cost.round(precision)
  def energy_cost_without_pv = comparison.cost_without_pv.round(precision)

  # { category => cost } of the compared payments (see
  # Heatpump::Comparison#payment_costs). They add up to the rounded payments
  # (see RoundedSum).
  def payment_costs
    @payment_costs ||= comparison.payment_costs.then { it.keys.zip(RoundedSum.new(it.values, unit: :money, precision:).parts).to_h }
  end

  def payments = payment_costs.values.sum

  def fuel_cost = comparison.fuel_cost.round(precision)
  def fixed_cost = comparison.fixed_cost.round(precision)

  # The total cost of each column
  def heatpump_cost = energy_cost + payments
  def without_pv_cost = energy_cost_without_pv + payments
  def heating_cost = fuel_cost + fixed_cost

  def savings = heating_cost - heatpump_cost
  def savings_without_pv = heating_cost - without_pv_cost

  private

  attr_reader :comparison
end
