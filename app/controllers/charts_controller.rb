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
      FluxChart.new(field.to_sym).now
    else
      FluxChart.new(field.to_sym).public_send(timeframe, timestamp)
    end
  end
end
