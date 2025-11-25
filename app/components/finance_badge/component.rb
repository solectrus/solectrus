class FinanceBadge::Component < ViewComponent::Base
  def initialize(data:, timeframe:)
    super()
    @data = data
    @timeframe = timeframe
  end
  attr_reader :data, :timeframe
end
