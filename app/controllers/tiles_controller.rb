class TilesController < ApplicationController
  include ParamsHandling

  def show
  end

  private

  # The sensor comes straight from the URL, so unlike the curated tiles of the
  # essentials page this can be asked for anything the registry knows - a power
  # split included. Those have no instantaneous value
  # (Sensor::Definitions::Base#instantaneous?), so the tile reports "---"
  # instead of dressing up a division of a period as a current reading. No UI
  # path builds such a link today; the guard is what keeps it that way.
  def data_now
    return no_live_value unless sensor.instantaneous?

    Sensor::Query::Latest.new([sensor.name]).call
  end

  def no_live_value
    Sensor::Data::Single.new({ sensor.name => nil }, timeframe:)
  end

  def data_range
    Sensor::Query::Total.new(timeframe) { |q| q.sum sensor.name, :sum }.call
  end
end
