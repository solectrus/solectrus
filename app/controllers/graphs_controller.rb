class GraphsController < ApplicationController
  def index
    @chart = FluxChart.new(:house_power).public_send(timeframe)
  end

  private

  helper_method def timeframe
    params[:timeframe]
  end
end
