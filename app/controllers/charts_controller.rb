class ChartsController < ApplicationController
  include ParamsHandling

  def index
    respond_to do |format|
      format.json { render ChartData::Component.new(field:, timeframe:) }
    end
  end
end
