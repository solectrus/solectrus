# The amounts of a comparison with a combustion car (see Car::Comparison) as
# the page shows them: each part in whole units, and each sum of the rounded
# parts. So the steps of a column add up on the page, and the savings are
# the difference of the shown totals. The costs per 100 km round to two
# decimals, and the savings per 100 km are their difference. The comparison
# itself stays exact.
class Car::ComparisonAmounts
  def initialize(comparison)
    @comparison = comparison
  end

  # { source => cost } of the sources of the energy, with and without the PV
  # system (see Car::Comparison#sources). They add up to the rounded cost of
  # the energy, which the car page shows too (see RoundedSum).
  def source_costs = @source_costs ||= rounded_costs(comparison.sources.transform_values(&:cost))
  def source_costs_without_pv = @source_costs_without_pv ||= rounded_costs(comparison.sources_without_pv.transform_values(&:cost))

  def energy_cost = source_costs.values.sum
  def energy_cost_without_pv = source_costs_without_pv.values.sum

  # { category => cost } of the payments of the car (see
  # Car::Comparison#payment_costs). They add up to the rounded payments.
  def payment_costs = @payment_costs ||= rounded_costs(comparison.payment_costs)

  # The payments of the car, and their part that the combustion car shares,
  # each from the rounded categories
  def payments = payment_costs.values.sum
  def shared_cost = payment_costs.slice(*Car::Payment::SHARED).values.sum

  def fuel_cost = comparison.fuel_cost.round
  def tax = comparison.tax.round

  # The total cost of each column
  def car_cost = energy_cost + payments
  def car_cost_without_pv = energy_cost_without_pv + payments
  def combustion_cost = fuel_cost + shared_cost + tax

  def savings = combustion_cost - car_cost
  def savings_without_pv = combustion_cost - car_cost_without_pv

  # A cost of the comparison per 100 km (`cost` names it, for example
  # :car_cost or :fuel_cost), nil without a distance. It comes from the
  # exact cost, because a whole unit of a small cost would change it by
  # much.
  def per_100km(cost) = comparison.per_100km(comparison.public_send(cost))&.round(2)

  def savings_per_100km
    combustion = per_100km(:combustion_cost)
    combustion - per_100km(:car_cost) if combustion
  end

  private

  attr_reader :comparison

  # { key => cost } in whole units, which add up to the rounded sum
  def rounded_costs(costs)
    return {} if costs.empty?

    costs.keys.zip(RoundedSum.new(costs.values, unit: :money, precision: 0).parts).to_h
  end
end
