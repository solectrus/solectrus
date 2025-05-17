class FinanceBadge::Component < ViewComponent::Base
  def initialize(calculator:, timeframe:)
    super
    @calculator = calculator
    @timeframe = timeframe
  end
  attr_reader :calculator, :timeframe

  def costs
    Setting.opportunity_costs ? calculator.total_costs : calculator.paid.abs
  end
end
