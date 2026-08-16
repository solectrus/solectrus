# The four home pages: power balance, house, heat pump and inverter. They
# differ in the sensors they show and in their default, not in their flow.
class HomePageController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation
  include SummaryChecker

  def index
    return redirect_to(balance_home_path) unless Sensor::HomePage.available?(page_key)
    return redirect_to(path_for(default_sensor_name, timeframe)) unless supported_sensor?
    return redirect_to(path_for(sensor_name)) unless timeframe
    return redirect_to(future_path) if timeframe.future? && future_path

    load_missing_or_stale_summary_days(timeframe)
  end

  private

  # Each page shows a fixed set of sensors. Without this check any
  # chart-enabled sensor renders on any page, so a hand-edited URL like
  # /house/wallbox_power/2026 shows the house page with a chart it never
  # offers, and no dropdown entry marked as current.
  #
  # The default counts as supported even when the page does not list it, so
  # the redirect cannot loop. A missing name is never supported, and answering
  # that first keeps the sensor list out of the param-less request. The page
  # comes before the default, because a default can be expensive to compute.
  def supported_sensor?
    return false unless sensor_name

    Sensor::HomePage.accepts?(page_key, sensor_name) ||
      sensor_name == default_sensor_name
  end

  # Only the sensor is wrong when the redirect swaps it, so a timeframe the
  # request already carries survives.
  def path_for(name, keep_timeframe = nil)
    url_for(
      action: 'index',
      sensor_name: name,
      timeframe: keep_timeframe || 'now',
    )
  end

  # Where a future timeframe goes. The forecast page takes it over, if the
  # installation has a forecast at all. Pages without one override this.
  def future_path
    forecast_path if Sensor::Config.exists?(:inverter_power_forecast)
  end
end
