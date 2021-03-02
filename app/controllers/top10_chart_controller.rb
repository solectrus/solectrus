class Top10ChartController < ApplicationController
  def index
    render formats: :turbo_stream
  end
end
