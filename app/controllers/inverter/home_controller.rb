class Inverter::HomeController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation
  include SummaryChecker

  def index
    unless Setting.enable_multi_inverter
      redirect_to(balance_home_path)
      return
    end

    unless sensor_name && timeframe
      redirect_to(default_path)
      return
    end

    if timeframe.future? && Sensor::Config.exists?(:inverter_power_forecast)
      redirect_to forecast_path
      return
    end

    load_missing_or_stale_summary_days(timeframe)
  end

  private

  def default_path
    inverter_home_path(
      sensor_name: sensor_name || :inverter_power,
      timeframe: 'now',
    )
  end
end
