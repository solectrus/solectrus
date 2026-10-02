# The tooltip of the charging cost on the car page. It gives the parts of
# the cost: PV and grid of the home wallbox and the offsite sessions. A guest
# session belongs to no car, so its cost is a loss of its own and not a part
# of the total.
class Car::ChargingCostTooltip::Component < ViewComponent::Base
  include CarRoundedCosts

  def initialize(balance:)
    super()
    @balance = balance
  end

  attr_reader :balance

  # The PV and the grid part, only with the power splitter
  def split?
    ApplicationPolicy.power_splitter? && balance.charge_split.split?
  end

  # The parts and the total, rounded so the parts add up to the total
  def costs
    @costs ||= rounded_costs(split? ? balance.charge_split.cost : { wallbox: wallbox_cost, offsite: offsite_cost.to_f })
  end

  def cost_value(cost, **)
    SensorValue::Component.new(cost, :total_costs, **costs.options, **)
  end

  def wallbox_cost = balance.session_totals(:wallbox)[:cost].to_f

  def offsite_cost = balance.session_totals(:offsite)[:cost]

  def guest_cost = balance.session_totals(:guest)[:cost]
end
