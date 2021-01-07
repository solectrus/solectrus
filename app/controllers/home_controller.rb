class HomeController < ApplicationController
  include ParamsHandling

  def index
    redirect_to root_path(timeframe: timeframe || 'now', field: field || 'inverter_power') unless timeframe && field
  end
end
