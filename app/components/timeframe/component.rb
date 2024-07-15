class Timeframe::Component < ViewComponent::Base
  def initialize(timeframe:)
    super
    @timeframe = timeframe
  end
  attr_reader :timeframe
end
