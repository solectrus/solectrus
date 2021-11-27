class StatsController < ApplicationController
  include ParamsHandling

  def index
    render formats: :turbo_stream
  end

  private

  helper_method def calculator
    @calculator ||=
      if period == 'now'
        Calculator::Now.new
      else
        Calculator::Range.new(period, timestamp)
      end
  end
end
