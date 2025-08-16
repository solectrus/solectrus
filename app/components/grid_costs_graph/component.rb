class GridCostsGraph::Component < ViewComponent::Base
  def initialize(costs:, revenue:)
    super()
    @costs = costs
    @revenue = revenue
  end

  attr_reader :costs, :revenue

  def max
    @max ||= [costs, revenue].max
  end

  def costs_width
    return 0 if max.zero?

    (costs.fdiv(max) * 100).round
  end

  def revenue_width
    return 0 if max.zero?

    (revenue.fdiv(max) * 100).round
  end

  def profit
    revenue - costs
  end
end
