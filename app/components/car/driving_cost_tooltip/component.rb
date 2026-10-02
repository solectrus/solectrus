# The tooltip of the driving cost on the car page. It shows how the driving
# cost comes from the distance and the cost rate. The distance holds only the
# days with a rate, like the rate (see Car::DailyRates). A note gives the
# kilometers of the days without a rate, which the distance of the card holds.
class Car::DrivingCostTooltip::Component < ViewComponent::Base
  def initialize(balance:)
    super()
    @balance = balance
  end

  attr_reader :balance

  delegate :car_cost_per_100km, :car_driving_costs, :car_distance, to: :balance

  def distance
    balance.driving.cost_distance
  end
end
