class SplittedCosts::Component < ViewComponent::Base
  # costs may be nil: the battery has a grid share worth showing, but no costs
  # of its own -- what it stores is billed to the consumers that take it back
  # out again, through their own grid share. Such a segment passes a note
  # saying so, otherwise the missing amount reads as "free".
  def initialize(power_grid_ratio:, costs: nil, grid_costs: nil, pv_costs: nil, note: nil, show_power_breakdown: true)
    super()
    @costs = costs
    @grid_costs = grid_costs
    @pv_costs = pv_costs
    @power_grid_ratio = power_grid_ratio
    @note = note
    @show_power_breakdown = show_power_breakdown
  end

  attr_reader :grid_costs, :pv_costs, :power_grid_ratio, :note

  # When breakdown is shown, calculate total from rounded parts
  # to ensure displayed values add up correctly
  def costs
    return @costs unless breakdown?

    display_rounded(grid_costs) + display_rounded(pv_costs)
  end

  def power_pv_ratio
    return unless power_grid_ratio

    100 - power_grid_ratio
  end

  def breakdown?
    grid_costs || pv_costs
  end

  def costs?
    !costs.nil?
  end

  def show_power_breakdown?
    @show_power_breakdown
  end

  private

  # Round a part the way it is displayed, so the total built from the parts
  # matches what the eye adds up.
  def display_rounded(value)
    Sensor::ValueFormatter.round_money(value.to_f)
  end
end
