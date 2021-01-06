class ChartsController < ApplicationController
  def index; end

  private

  helper_method def timeframe
    params[:timeframe]
  end

  helper_method def field
    params[:field]
  end

  helper_method def chart
    @chart ||= FluxChart.new(field.to_sym).public_send(timeframe)
  end
end
