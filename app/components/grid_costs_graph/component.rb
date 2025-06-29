class GridCostsGraph::Component < ViewComponent::Base
  def initialize(costs:, revenue:)
    super
    @costs = costs
    @revenue = revenue
  end

  attr_reader :costs, :revenue

  def max
    @max ||= [costs, revenue].max
  end

  def costs_width
    @costs_width ||= (costs.fdiv(max) * 100).round
  end

  def revenue_width
    @revenue_width ||= (revenue.fdiv(max) * 100).round
  end

  def profit
    @profit ||= revenue - costs
  end
end
