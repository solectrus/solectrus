# @label GridCostsGraph
class GridCostsGraphComponentPreview < ViewComponent::Preview
  # @!group Misc

  # @label Default
  def default
    render GridCostsGraph::Component.new(costs: 100, revenue: 30)
  end

  # @label Small Costs
  def small_costs
    render GridCostsGraph::Component.new(costs: 10, revenue: 300)
  end

  # @label Small Revenue
  def with_small_revenue
    render GridCostsGraph::Component.new(costs: 100, revenue: 5)
  end

  # @!endgroup
end
