class Heatpump::HomeController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation
  include SummaryChecker

  def index
    unless Setting.enable_heatpump
      redirect_to(balance_home_path)
      return
    end

    unless sensor_name && timeframe
      redirect_to(default_path)
      return
    end

    unless valid_chart_name?
      redirect_to(heatpump_home_path(sensor_name:, timeframe:))
      return
    end

    if timeframe.future?
      redirect_to(default_path)
      return
    end

    load_missing_or_stale_summary_days(timeframe)
  end

  private

  def default_path
    heatpump_home_path(
      sensor_name: sensor_name || :heatpump_heating_power,
      timeframe: 'now',
    )
  end
end
