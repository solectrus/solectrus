class StatsController < ApplicationController
  include ParamsHandling

  def index; end

  private

  helper_method def calculator
    @calculator ||= if timeframe == 'now'
      Calculator::Now.new
    else
      Calculator::Range.new(timeframe, timestamp)
    end
  end
end
