class ChartLoader::Component < ViewComponent::Base
  def initialize(sensor_name:, timeframe:, variant: nil)
    super()
    @sensor = Sensor::Registry[sensor_name]
    @timeframe = timeframe
    @variant = variant
  end
  attr_reader :sensor, :timeframe, :variant

  delegate :type,
           :data,
           :options,
           :blank?,
           :unit,
           :permitted?,
           :permitted_feature_name,
           to: :chart

  def blank_message
    I18n.t('data.blank')
  end

  def path_to_insights
    return if timeframe.now?
    return unless sensor.trendable?

    helpers.insights_path(sensor_name: sensor.name, timeframe:)
  end

  def demo_url
    {
      controller: "#{helpers.controller_namespace}/home",
      sensor_name: sensor.name,
      timeframe:,
    }
  end

  def show_forecast_comment?
    chart.respond_to?(:forecast_deviation)
  end

  def chart
    @chart ||= sensor.chart(timeframe, variant:)
  end
end
