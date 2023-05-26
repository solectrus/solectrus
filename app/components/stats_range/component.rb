class StatsRange::Component < ViewComponent::Base
  def initialize(calculator:, timeframe:)
    super
    @calculator = calculator
    @timeframe = timeframe
  end

  attr_accessor :calculator, :timeframe
end
