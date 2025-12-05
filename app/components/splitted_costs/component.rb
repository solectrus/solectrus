class SplittedCosts::Component < ViewComponent::Base
  def initialize(costs:, power_grid_ratio:, grid_costs: nil, pv_costs: nil)
    super()
    @costs = costs
    @grid_costs = grid_costs
    @pv_costs = pv_costs
    @power_grid_ratio = power_grid_ratio
  end

  attr_reader :grid_costs, :pv_costs, :power_grid_ratio

  # When breakdown is shown, calculate total from rounded parts
  # to ensure displayed values add up correctly
  def costs
    return @costs unless breakdown?

    grid_costs.to_f.round(2) + pv_costs.to_f.round(2)
  end

  def power_pv_ratio
    return unless power_grid_ratio

    100 - power_grid_ratio
  end

  def breakdown?
    grid_costs || pv_costs
  end
end
