class SplittedCosts::Component < ViewComponent::Base
  def initialize(costs:, power_grid_ratio:, approximate: false)
    super()
    @costs = costs

    @power_grid_ratio = power_grid_ratio
    @approximate = approximate
  end

  attr_reader :costs, :power_grid_ratio, :approximate

  def power_pv_ratio
    return unless power_grid_ratio

    100 - power_grid_ratio
  end
end
