class HomeController < ApplicationController
  def index
    redirect_to root_path(timeframe: 'now', field: 'inverter_power') unless timeframe || field
  end

  helper_method def timeframe
    params[:timeframe]
  end

  helper_method def field
    params[:field]
  end
end
