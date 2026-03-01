class ChartLoader::Component < ViewComponent::Base
  def initialize(sensor_name:, timeframe:, variant: nil, interval: nil)
    super()
    @sensor = Sensor::Registry[sensor_name]
    @timeframe = timeframe
    @variant = variant
    @interval = interval
  end
  attr_reader :sensor, :timeframe, :variant, :interval

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

  def icon_button_class
    'flex items-center justify-center p-2 font-medium focus:outline-none focus:ring-2 focus:ring-gray-700 dark:focus:ring-gray-400 text-sm gap-2 hover:bg-gray-200 dark:hover:bg-gray-700 bg-gray-100 dark:bg-gray-800 rounded-full size-8 border border-gray-300 dark:border-gray-600 cursor-pointer'
  end

  def zoom_interval
    return unless timeframe.day?

    '1m'
  end

  def chart
    @chart ||=
      sensor.chart(timeframe, variant:)&.tap do |c|
        c.interval = interval
      end
  end
end
