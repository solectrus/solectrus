class StatsController < ApplicationController
  def index
    redirect_to root_path(timeframe: 'current') unless timeframe
  end

  private

  helper_method def timeframe
    params[:timeframe]
  end

  helper_method def calculator
    @calculator ||= Calculator.new(timeframe)
  end
end
