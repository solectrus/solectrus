class FinanceBadge::Component < ViewComponent::Base
  def initialize(data:, timeframe:)
    super()
    @data = data
    @timeframe = timeframe
  end
  attr_reader :data, :timeframe

  def costs
    Setting.opportunity_costs ? data.total_costs : data.grid_costs
  end
end
