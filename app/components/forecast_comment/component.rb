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

  # Threshold for significant deviation (0.5 kWh = 500 Wh)
  DEVIATION_THRESHOLD = 500
  private_constant :DEVIATION_THRESHOLD

  def tooltip_required?
    return false if future? || today_before_sunset?

    deviation = data.forecast_deviation
    deviation && deviation.abs > DEVIATION_THRESHOLD
  end
end
