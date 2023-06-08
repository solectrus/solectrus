class StatsRange::Component < ViewComponent::Base
  def initialize(calculator:, timeframe:, field:)
    super
    @calculator = calculator
    @timeframe = timeframe
    @field = field
  end

  attr_accessor :calculator, :timeframe, :field
end
