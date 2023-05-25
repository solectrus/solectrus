class ChartsController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation

  def index
    render formats: :turbo_stream
  end

  private

  helper_method def calculator
    @calculator ||=
      (timeframe.now? ? Calculator::Now.new : Calculator::Range.new(timeframe))
  end
end
