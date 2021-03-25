class Top10ChartController < ApplicationController
  include ParamsHandling

  def index
    render formats: :turbo_stream
  end
end
