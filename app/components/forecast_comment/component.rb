class ForecastComment::Component < ViewComponent::Base
  def initialize(data:, sensor_name:, timeframe:, chart: nil)
    super()
    @data = data
    @sensor_name = sensor_name
    @timeframe = timeframe
    @chart = chart
  end

  attr_accessor :data, :sensor_name, :timeframe, :chart

  delegate :sunrise, :sunset, to: :day_light, allow_nil: true

  def remaining_forecast_wh
    return unless chart.respond_to?(:remaining_forecast_wh)

    chart.remaining_forecast_wh
  end

  def today_before_sunset?
    timeframe.today? && sunset&.future?
  end

  def today_before_sunrise?
    timeframe.today? && sunrise&.future?
  end

  def today_during_daylight?
    !today_before_sunrise? && today_before_sunset?
  end

  def day_light
    @day_light ||= Sensor::Query::DayLight.new(timeframe.date)
  end

  # Threshold for significant deviation (0.5 kWh = 500 Wh)
  DEVIATION_THRESHOLD = 500
  private_constant :DEVIATION_THRESHOLD

  def forecast_deviation
    return unless data.respond_to?(:forecast_deviation)

    data.forecast_deviation
  end

  def forecast_available?
    forecast_deviation.present?
  end

  def show_remaining_forecast?
    today_during_daylight? && remaining_forecast_wh
  end

  def show_full_forecast?
    today_before_sunset?
  end

  def better_than_expected?
    forecast_deviation && forecast_deviation > DEVIATION_THRESHOLD
  end

  def worse_than_expected?
    forecast_deviation && forecast_deviation < -DEVIATION_THRESHOLD
  end

  def tooltip_required?
    return false if today_before_sunset?

    forecast_deviation && forecast_deviation.abs > DEVIATION_THRESHOLD
  end
end
