class HomeController < ApplicationController
  def index
    redirect_to root_path(timeframe: 'now') unless timeframe
  end

  helper_method def timeframe
    params[:timeframe]
  end
end
