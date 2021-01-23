class ChartsController < ApplicationController
  include ParamsHandling

  def index
    respond_to do |format|
      format.json { render json: chart }
    end
  end

  private

  helper_method def chart
    @chart ||= if timeframe == 'now'
      PowerChart.new(fields: [field], measurements: ['SENEC']).now
    else
      PowerChart.new(fields: [field], measurements: ['SENEC']).public_send(timeframe, timestamp)
    end
  end
end
