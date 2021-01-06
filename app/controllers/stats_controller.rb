class StatsController < ApplicationController
  def index
    redirect_to root_path(timeframe: 'now', field: 'inverter_power') unless timeframe || field
  end

  private

  helper_method def timeframe
    params[:timeframe]
  end

  helper_method def field
    params[:field]
  end

  helper_method def calculator
    @calculator ||= if timeframe == 'now'
      NowCalculator.new
    else
      RangeCalculator.new(timeframe)
    end
  end
end
