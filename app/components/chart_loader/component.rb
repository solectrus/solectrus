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
           :blank_message,
           :blank_icon,
           :unit,
           :decimals,
           :scalable?,
           :permitted?,
           :permitted_feature_name,
           to: :chart

  ICON_BUTTON_CLASS = 'flex items-center justify-center p-2 font-medium focus:outline-none focus:ring-2 focus:ring-gray-700 dark:focus:ring-gray-400 text-sm gap-2 hover:bg-gray-200 dark:hover:bg-gray-700 bg-gray-100 dark:bg-gray-800 rounded-full size-8 border border-gray-300 dark:border-gray-600 cursor-pointer relative touch-target'
    .freeze
  private_constant :ICON_BUTTON_CLASS

  # A zoomed chart fills the window (see chart_zoom_controller.ts)
  ZOOM_CLASSES = 'min-h-20 flex flex-col group/zoom group-data-zoomed/zoom:fixed group-data-zoomed/zoom:inset-0 group-data-zoomed/zoom:z-45 group-data-zoomed/zoom:p-6 group-data-zoomed/zoom:bg-white dark:group-data-zoomed/zoom:bg-slate-900'
    .freeze
  private_constant :ZOOM_CLASSES

  # The buttons stand at the top right, beside the chart menu. A map reaches
  # the edges of the card, so its buttons keep the padding of the card, and
  # beside the stats they float on the map like the chart menu.
  #
  # z-6, not z-10: above the canvas and the loading overlay (z-5), but below
  # the header, whose own stacking context is z-10. At the same level these
  # buttons would cover a menu opened from the navigation above them.
  def controls_classes
    class_names(
      'absolute top-0 flex gap-3 z-6 group-data-zoomed/zoom:right-4 group-data-zoomed/zoom:top-4',
      chart_component ? 'right-4 sm:right-6 lg:landscape:top-3 lg:landscape:right-3' : 'right-0',
    )
  end

  def currency
    Currency.symbol
  end

  def path_to_insights
    return if timeframe.now?
    return unless sensor.trendable?

    # The car page keeps its selected car (see Car::Insights::Component)
    helpers.insights_path(sensor_name: sensor.name, timeframe:, **helpers.selection_params)
  end

  def demo_url
    {
      controller: "#{helpers.controller_namespace}/home",
      sensor_name: sensor.name,
      timeframe:,
    }
  end

  # A guest gets the chart of an admin-only sensor without its data, and a
  # hint (see the `admin_only` DSL)
  def teaser?
    sensor.admin_only? && !helpers.admin?
  end

  # The component of a chart that is no canvas, like the map of the places
  def chart_component
    return @chart_component if defined?(@chart_component)

    @chart_component = chart.component
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
        # The selection of the page, like the cars of the car page
        sensor.chart(timeframe, variant:, **helpers.chart_options)&.tap do |c|
          c.interval = timeframe.day? ? interval : nil
        end
      end
  end
end
