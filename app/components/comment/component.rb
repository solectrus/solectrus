class Comment::Component < ViewComponent::Base
  def initialize(calculator:, field:, period:, timestamp:)
    super
    @calculator = calculator
    @field = field
    @period = period
    @timestamp = timestamp
  end

  attr_accessor :calculator, :field, :period, :timestamp
end
