class House::HomeController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation
  include SummaryChecker

  def index
    unless Setting.enable_custom_consumer
      redirect_to(balance_home_path)
      return
    end

    unless sensor_name && timeframe
      redirect_to(default_path)
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
    house_home_path(sensor_name: sensor_name || :house_power, timeframe: 'now')
  end
end
