class Comment::Component < ViewComponent::Base
  def initialize(calculator:, field:, timeframe:)
    super
    @calculator = calculator
    @field = field
    @timeframe = timeframe
  end

  attr_accessor :calculator, :field, :timeframe
end
