class TilesController < ApplicationController
  include ParamsHandling

  # The route admits every sensor of the registry, the permission aside
  before_action { head(:not_found) if Sensor::Config.withheld?(sensor.name) }

  # A chart of the car page tells when the cars drove and charged, so only the
  # admin sees its total of a period with today or yesterday (see
  # Car::AdminOnlyDays). An older period stays public, like on the car page.
  before_action { head(:not_found) if admin_only_days? }

  def show
  end

  private

  def admin_only_days?
    !admin? && sensor.is_a?(Sensor::Definitions::CarPageChart) && !timeframe.now? &&
      Car::AdminOnlyDays.overlap?(timeframe)
  end

  # The sensor comes straight from the URL, so unlike the curated tiles of the
  # essentials page this can be asked for anything the registry knows - a power
  # split included. Those have no instantaneous value
  # (Sensor::Definitions::Base#instantaneous?), so the tile reports "---"
  # instead of dressing up a division of a period as a current reading. No UI
  # path builds such a link today; the guard is what keeps it that way.
  def data_now
    return no_value unless sensor.instantaneous?

    Sensor::Query::Latest.new([sensor.name]).call
  end

  def no_value
    Sensor::Data::Single.new({ sensor.name => nil }, timeframe:)
  end

  # The tile shows the sum of a period. A sensor without one, like a
  # percentage, a temperature or a chart of the car page, reports "---" for
  # the same reason as above.
  def data_range
    return no_value if sensor.allowed_aggregations.exclude?(:sum)

    Sensor::Query::Total.new(timeframe) { |q| q.sum sensor.name, :sum }.call
  end
end
