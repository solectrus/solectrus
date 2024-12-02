class SplittedCosts::Component < ViewComponent::Base
  def initialize(costs:, power_grid_ratio:)
    super()
    @costs = costs

    @power_grid_ratio = power_grid_ratio
  end

  attr_reader :costs, :power_grid_ratio

  def power_pv_ratio
    return unless power_grid_ratio

    100 - power_grid_ratio
  end
end
