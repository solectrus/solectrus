class GraphsController < ApplicationController
  def index
    @chart = FluxChart.new(field.to_sym).public_send(timeframe)
  end

  private

  helper_method def timeframe
    params[:timeframe]
  end

  helper_method def field
    params[:field]
  end
end
