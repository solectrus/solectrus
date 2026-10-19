# The driving of a set of days. The distance holds only the days with an
# energy rate, and the cost distance only the days with a cost rate.
Car::Driving::Totals = Data.define(:distance, :energy_wh, :cost_distance, :cost)

# The methods sit in a class body, like those of ChargingSession::Sums. A
# static index (Lint/ArgumentMismatch) puts a `def self.` of the block of
# Data.define on Object, where it clashes with each other `sum`.
class Car::Driving::Totals
  def self.empty = new(distance: 0.0, energy_wh: 0.0, cost_distance: 0.0, cost: 0.0)

  # The sum of a list of Totals in one pass
  def self.sum(list)
    return empty if list.empty?

    new(**members.index_with { |member| list.sum(&member) })
  end

  def rated? = distance.positive?

  def cost_rated? = cost_distance.positive?

  # Energy is in Wh, so /10 turns Wh per km into kWh per 100 km
  def consumption_per_100km
    (energy_wh / 10.0).fdiv(distance) if rated?
  end

  def cost_per_100km
    (cost * 100.0).fdiv(cost_distance) if cost_rated?
  end
end
