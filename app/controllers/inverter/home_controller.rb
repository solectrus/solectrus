class Inverter::HomeController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation
  include SummaryChecker

  def index
    unless sensor && timeframe
      redirect_to(default_path)
      return
    end

    load_missing_or_stale_summary_days(timeframe)
  end

  private

  def default_path
    inverter_home_path(sensor: sensor || 'inverter_power', timeframe: 'now')
  end
end
