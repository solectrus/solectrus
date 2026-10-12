# The home pages: power balance, house, heat pump, inverter and car. They
# differ in the sensors they show and in their default, not in their flow.
class HomePageController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation
  include SummaryChecker
  include TimeframeSelectModal

  # The page decides what it may show and what its upsell names, and both
  # answers come from the key (see Sensor::HomePage).
  helper_method :page_key

  def index # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    return redirect_to(balance_home_path) unless Sensor::HomePage.available?(page_key)
    return redirect_to(path_for(default_sensor_name, timeframe)) unless supported_sensor?
    return redirect_to(path_for(sensor_name)) unless timeframe
    return redirect_to(path_for(sensor_name, 'day')) if timeframe.hours? && !Sensor::HomePage.hours?(page_key)
    return redirect_to(future_path) if timeframe.future? && future_path
    return redirect_to(path_for(sensor_name, timeframe)) unless offered_selection?

    load_missing_or_stale_summary_days(timeframe)
  end

  private

  # The addresses of the page for its timeframe select. They keep the
  # selection of the page, like the car (see #selection_params).
  helper_method def timeframe_page
    TimeframePage::Sensor.new(namespace: controller_path.split('/').first, sensor_name: chart_sensor_name, params: selection_params)
  end

  # Each page shows a fixed set of sensors. Without this check any
  # chart-enabled sensor renders on any page, so a hand-edited URL like
  # /house/wallbox_power/2026 shows the house page with a chart it never
  # offers, and no dropdown entry marked as current.
  #
  # The default counts as supported even when the page does not list it, so
  # the redirect cannot loop. A missing name is never supported, and answering
  # that first keeps the sensor list out of the param-less request. The page
  # comes before the default, because a default can be expensive to compute.
  #
  # A chart that cannot draw the timeframe or the selection of the page, for
  # example a rate of the car page on a day, goes to the default as well,
  # which keeps the timeframe and the selection.
  def supported_sensor?
    return false unless sensor_name
    return sensor_name == default_sensor_name unless Sensor::HomePage.accepts?(page_key, sensor_name)

    timeframe.nil? || supported_chart?(sensor_name) || sensor_name == default_sensor_name
  end

  # Whether the chart draws the timeframe and the selection of the page. A
  # sensor without a chart has nothing to refuse.
  def supported_chart?(name)
    Sensor::Registry[name].chart(timeframe, **chart_options)&.supported? != false
  end

  # Only the sensor is wrong when the redirect swaps it, so a timeframe the
  # request already carries survives.
  def path_for(name, keep_timeframe = nil)
    url_for(
      action: 'index',
      sensor_name: name,
      timeframe: keep_timeframe || 'now',
      **selection_params,
    )
  end

  # Whether the page offers the selection of the request (see
  # ApplicationController#selection_params). Otherwise the page goes to the
  # same address without it.
  def offered_selection? = true

  # Where a future timeframe goes. The forecast page takes it over, if the
  # installation has a forecast at all. Pages without one override this.
  def future_path
    forecast_path if Sensor::Config.exists?(:inverter_power_forecast)
  end
end
