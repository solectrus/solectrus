class ForecastComment::Component < ViewComponent::Base
  def initialize(data:, sensor_name:, timeframe:)
    super()
    @data = data
    @sensor_name = sensor_name
    @timeframe = timeframe
  end

  attr_accessor :data, :sensor_name, :timeframe

  def today_before_sunset?
    timeframe.today? && sunset&.future?
  end

  def future?
    !timeframe.past? && !timeframe.current?
  end

  def sunset
    @sunset ||= Sensor::Query::DayLight.new(timeframe.date)&.sunset
  end

  def tooltip_required?
    data.forecast_deviation&.positive? ||
      (!(future? || today_before_sunset?) && data.forecast_deviation&.negative?)
  end
end
