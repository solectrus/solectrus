class ChartsController < ApplicationController
  include ParamsHandling

  def index
    respond_to do |format|
      format.json do
        render ChartData::Component.new(
                 field: field,
                 period: period,
                 timestamp: timestamp,
               )
      end
    end
  end
end
