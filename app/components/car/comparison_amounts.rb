# The amounts of a comparison with a combustion car (see Car::Comparison) as
# the page shows them: each part rounded to the decimals of the page (see
# #precision), and each sum of the rounded parts. So the steps of a column
# add up on the page, and the savings are the difference of the shown
# totals. The costs per 100 km round to two decimals, and the savings per
# 100 km are their difference. The comparison itself stays exact.
class Car::ComparisonAmounts
  def initialize(comparison)
    @comparison = comparison
  end

  # The decimals of all amounts: those of the highest total cost as a
  # single amount (see Sensor::Units::Money), so cents when each total is
  # small, for example of a day. A day has a small part of each yearly
  # payment, and in whole units a tax of 0.63 and an insurance of 1.11
  # would both be 1. All amounts share the decimals, so the columns have one
  # format and add up.
  def precision
    @precision ||= Sensor::ValueFormatter.new([comparison.car_cost, comparison.car_cost_without_pv, comparison.combustion_cost].max_by(&:abs), unit: :money).precision
  end

  # { source => cost } of the sources of the energy, with and without the PV
  # system (see Car::Comparison#sources). They add up to the rounded cost of
  # the energy, which the car page shows too (see RoundedSum).
  def source_costs = @source_costs ||= rounded_sources(comparison.sources)
  def source_costs_without_pv = @source_costs_without_pv ||= rounded_sources(comparison.sources_without_pv)

  def energy_cost = source_costs.values.sum
  def energy_cost_without_pv = source_costs_without_pv.values.sum

  # { category => cost } of the payments of the car (see
  # Car::Comparison#payment_costs). They add up to the rounded payments.
  def payment_costs = @payment_costs ||= rounded_costs(comparison.payment_costs)

  # The payments of the car, and their part that the combustion car shares,
  # each from the rounded categories
  def payments = payment_costs.values.sum
  def shared_cost = payment_costs.slice(*Car::Payment::SHARED).values.sum

  def fuel_cost = comparison.fuel_cost.round(precision)
  def tax = comparison.tax.round(precision)

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

  # The offsite cost is the same in both columns of the car, so it rounds on
  # its own, and another source takes the rest of the rounded sum (see
  # RoundedSum): the grid, or the PV system without it.
  def rounded_sources(sources)
    costs = sources.transform_values(&:cost)
    rounded_costs(costs, rest: costs.keys.rindex { it != :offsite })
  end

  # { key => cost } rounded to #precision, which add up to the rounded sum.
  # The part at the index `rest` takes the rest, the last one without it.
  def rounded_costs(costs, rest: nil)
    return {} if costs.empty?

    costs.keys.zip(RoundedSum.new(costs.values, rest:, unit: :money, precision:).parts).to_h
  end
end
