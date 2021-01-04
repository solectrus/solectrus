class GraphsController < ApplicationController
  def index
    @chart = FluxQuery.new(:house_power).public_send("#{timeframe}_chart")
  end

  private

  helper_method def timeframe
    params[:timeframe]
  end
end
