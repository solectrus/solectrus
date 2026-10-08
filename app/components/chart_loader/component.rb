class ChartLoader::Component < ViewComponent::Base
  # `year_comparison` is given rather than read from the controller, because
  # the forecast page renders this component too and has no such parameter.
  # It names the comparison ("by_month", "by_quarter"), or nothing at all.
  def initialize(
    sensor_name:,
    timeframe:,
    variant: nil,
    interval: nil,
    year_comparison: nil
  )
    super()
    @sensor = Sensor::Registry[sensor_name]
    @timeframe = timeframe
    @variant = variant
    @interval = interval
    @year_comparison = year_comparison
  end
  attr_reader :sensor, :timeframe, :variant, :interval, :year_comparison

  delegate :type,
           :data,
           :options,
           :blank?,
           :unit,
           :permitted?,
           :permitted_feature_name,
           to: :chart

  ICON_BUTTON_CLASS = 'flex items-center justify-center p-2 font-medium focus:outline-none focus:ring-2 focus:ring-gray-700 dark:focus:ring-gray-400 text-sm gap-2 hover:bg-gray-200 dark:hover:bg-gray-700 bg-gray-100 dark:bg-gray-800 rounded-full size-8 border border-gray-300 dark:border-gray-600 cursor-pointer relative touch-target'
    .freeze
  private_constant :ICON_BUTTON_CLASS

  def blank_message
    I18n.t('data.blank')
  end

  def currency
    Currency.symbol
  end

  def path_to_insights
    helpers.sensor_insights_path(sensor, timeframe:)
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

  def zoom_interval
    return unless timeframe.day?

    '1m'
  end

  def chart
    @chart ||=
      if (comparison = Sensor::Chart::YearComparison.for(year_comparison))
        comparison.new(timeframe:, sensor_name: sensor.name)
      else
        sensor.chart(timeframe, variant:)&.tap do |c|
          c.interval = timeframe.day? ? interval : nil
        end
      end
  end
end
