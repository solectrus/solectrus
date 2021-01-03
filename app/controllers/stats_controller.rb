class StatsController < ApplicationController
  def index
    redirect_to root_path(timeframe: 'current') unless timeframe

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace('stats', partial: timeframe == 'current' ? 'current' : 'range') +
                             turbo_stream.replace('live', partial: 'live_indicator')
      end
      format.html
    end
  end

  private

  helper_method def timeframe
    params[:timeframe]
  end

  helper_method def calculator
    @calculator ||= if timeframe == 'current'
      CurrentCalculator.new
    else
      RangeCalculator.new(timeframe)
    end
  end
end
