class Car::HomeController < ApplicationController
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
    car_home_path(sensor: sensor || 'car_driving_distance', timeframe: 'now')
  end
end
