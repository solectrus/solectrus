class Comment::Component < ViewComponent::Base
  def initialize(calculator:, field:, timeframe:, timestamp:)
    super
    @calculator = calculator
    @field = field
    @timeframe = timeframe
    @timestamp = timestamp
  end

  attr_accessor :calculator, :field, :timeframe, :timestamp
end
