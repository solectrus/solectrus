class StatsController < ApplicationController
  include ParamsHandling

  def index; end

  private

  helper_method def calculator
    @calculator ||= if timeframe == 'now'
      NowCalculator.new
    else
      RangeCalculator.new(timeframe, timestamp)
    end
  end
end
