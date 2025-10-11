class TilesController < ApplicationController
  include ParamsHandling

  def show
  end

  private

  def data_now
    Sensor::Query::Influx::Latest.new([sensor.name]).call
  end

  def data_range
    Sensor::Query::Sql
      .new do |q|
        q.sum sensor.name, :sum
        q.timeframe timeframe
      end
      .call
  end
end
