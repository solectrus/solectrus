class ForecastComment::Component < ViewComponent::Base
  def initialize(calculator:, sensor:, timeframe:)
    super()
    @calculator = calculator
    @sensor = sensor
    @timeframe = timeframe
  end

  attr_accessor :calculator, :sensor, :timeframe

  def today_before_sunset?
    timeframe.today? && sunset&.future?
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
