class ChartLoader::Component < ViewComponent::Base
  def initialize(sensor_name:, timeframe:, variant: nil)
    super()
    @sensor_name = sensor_name
    @timeframe = timeframe
    @variant = variant
  end
  attr_reader :sensor_name, :timeframe, :variant

  delegate :type, :data, :options, :blank?, :unit, :permitted?, to: :chart_instance

  def blank_message
    I18n.t('data.blank')
  end

  def path_to_insights
    return if timeframe.now?
    return unless sensor.trendable?

    helpers.insights_path(sensor_name:, timeframe:)
  end

  private

  def sensor
    @sensor ||= Sensor::Registry[sensor_name]
  end

  def chart_instance
    @chart_instance ||=
      (variant ? sensor.chart(timeframe, variant:) : sensor.chart(timeframe))
  end
end
