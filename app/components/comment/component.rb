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
    @sunset ||= DayLight.new(timeframe.date)&.sunset
  end

  def tooltip_required?
    calculator.forecast_deviation.positive? ||
      (
        !(future? || today_before_sunset?) &&
          calculator.forecast_deviation.negative?
      )
  end
end
