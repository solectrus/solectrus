class SplittedCosts::Component < ViewComponent::Base
  def initialize(costs:, power_grid_ratio:, grid_costs: nil, pv_costs: nil)
    super()
    @costs = costs
    @grid_costs = grid_costs
    @pv_costs = pv_costs
    @power_grid_ratio = power_grid_ratio
  end

  attr_reader :costs, :grid_costs, :pv_costs, :power_grid_ratio

  def power_pv_ratio
    return unless power_grid_ratio

    100 - power_grid_ratio
  end

  def breakdown?
    grid_costs || pv_costs
  end
end
