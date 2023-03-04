class Comment::Component < ViewComponent::Base
  def initialize(calculator:, field:, timeframe:)
    super
    @calculator = calculator
    @field = field
    @timeframe = timeframe
  end

  attr_accessor :calculator, :field, :timeframe

  def today_before_sunset?
    timeframe.day? && timeframe.current? && sunset && Time.current < sunset
  end

  def future?
    !timeframe.past? && !timeframe.current?
  end

  def sunset
    @sunset ||= Sunset.new(timeframe.date)&.time
  end
end
