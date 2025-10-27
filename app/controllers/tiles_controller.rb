class TilesController < ApplicationController
  include ParamsHandling

  def show
  end

  private

  def data_now
    Sensor::Query::Latest.new([sensor.name]).call
  end

  def data_range
    Sensor::Query::Total.new(timeframe) { |q| q.sum sensor.name, :sum }.call
  end
end
