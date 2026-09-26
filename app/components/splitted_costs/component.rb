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

  attr_reader :power_grid_ratio, :note

  # With a breakdown, the total is the one the key figures show, and the parts
  # add up to it as shown: 2,323 and 3,504 show as 2,32 + 3,51 = 5,83, not
  # 2,32 + 3,50.
  def costs
    breakdown? ? rounded.sum : @costs
  end

  def grid_costs
    rounded.parts.first if @grid_costs
  end

  def pv_costs
    rounded.parts.last if @pv_costs
  end

  # All amounts of the breakdown share one precision, so 4,83 + 10,20 = 15,03
  # instead of 4,83 + 10 = 15
  def precision
    rounded.precision if breakdown?
  end

  def power_pv_ratio
    return unless power_grid_ratio

    100 - power_grid_ratio
  end

  def breakdown?
    @grid_costs || @pv_costs
  end

  def costs?
    !costs.nil?
  end

  def show_power_breakdown?
    @show_power_breakdown
  end

  private

  def rounded
    @rounded ||= RoundedSum.new([@grid_costs.to_f, @pv_costs.to_f], unit: :money)
  end
end
