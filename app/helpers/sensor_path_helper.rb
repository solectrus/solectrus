module SensorPathHelper
  # The chart of a sensor lives on the home page that shows it, so its path
  # carries that page (/house/washing_machine/2026). This helper is the only
  # place that has to know. Everywhere else asks for a path and gets one that
  # the target page really answers.
  #
  # `params` are those of a selection, like the car of the car page.
  def sensor_home_path(sensor_name, timeframe:, **params)
    public_send(sensor_path_helpers[sensor_name], sensor_name:, timeframe:, **params)
  end

  # The way to the trends beside the timeframe of a home page
  # (Timeframe::TrendsButton::Component): the trend overview of the page
  # for a month, a year or the whole time, or without the permission a
  # teaser in its place. A shorter period has none, and a page beside a home
  # page, like the savings of the heat pump, neither. A visitor of the car
  # page sees fewer days, as in the trends (see TrendsController#timeframe).
  def page_trends_path(timeframe:)
    return unless home_page_request? && timeframe

    shown = controller_namespace == 'cars' && !admin? ? Car::AdminOnlyDays.public_timeframe(timeframe) : timeframe
    return unless TrendOverview.page_period?(page: controller_namespace, timeframe: shown)

    trends_path(timeframe:, **selection_params)
  end

  # The details of a sensor, which a long press on a segment opens on a
  # phone: the values of the sensor in the period, without a comparison,
  # which the trends show (see above). A sensor without a trend and the
  # current values have none. Without the permission, the details hold no
  # more than the tooltip, so the long press opens the tooltip itself.
  def sensor_insights_path(sensor, timeframe:)
    return if timeframe.now?
    return unless sensor.trendable?
    return unless ApplicationPolicy.trends?

    insights_path(sensor_name: sensor.name, timeframe:)
  end

  private

  # A request of a home page itself, its stats or its chart
  def home_page_request?
    controller_name.in?(%w[home stats charts]) && Sensor::HomePage.all.include?(controller_namespace.to_sym)
  end

  # A heatmap asks once per day and a Top10 table once per row, always for the
  # same sensor. Finding the page reads the sensor list of every page, so the
  # answer stays for the rest of the render.
  def sensor_path_helpers
    @sensor_path_helpers ||=
      Hash.new do |cache, sensor_name|
        cache[sensor_name] = :"#{Sensor::HomePage.page_for(sensor_name)}_home_path"
      end
  end
end
