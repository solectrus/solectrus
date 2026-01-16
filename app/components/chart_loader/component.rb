class ChartLoader::Component < ViewComponent::Base
  def initialize(sensor_name:, timeframe:, variant: nil, chart_name: nil, forecast_data: nil)
    super()
    @sensor_name = sensor_name
    @timeframe = timeframe
    @variant = variant
    @chart_name = chart_name
    @forecast_data = forecast_data
  end
  attr_reader :sensor_name, :timeframe, :variant, :chart_name, :forecast_data

  delegate :type, :data, :options, :blank?, :unit, :permitted?, to: :chart

  def blank_message
    I18n.t('data.blank')
  end

  def path_to_insights
    return if timeframe.now?
    return if chart_name
    return unless sensor.trendable?

    helpers.insights_path(sensor_name:, timeframe:)
  end

  private

  def sensor
    @sensor ||= Sensor::Registry[sensor_name]
  end

  def chart
    @chart ||= sensor.chart(timeframe, variant:, chart_name:)
  end
end
