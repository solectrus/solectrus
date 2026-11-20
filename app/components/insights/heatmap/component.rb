# The calendar of the insights of a year or of the whole time: on a phone a
# page of its own, which a row pushes into the sheet, on a larger screen a
# part of the list. It belongs to the insights--component controller of the
# list around it (Insights::Component, Insights::Comparison::Component). Its
# way back names the list, by `label` where the list has a name of its own.
# `tile` are the options of the grid (Insights::HeatmapTile::Component).
class Insights::Heatmap::Component < ViewComponent::Base
  def initialize(data:, sensor:, timeframe:, label: sensor.display_name, tile: {})
    super()
    @label = label
    @tile = tile
    @data = data
    @sensor = sensor
    @timeframe = timeframe
  end

  attr_reader :data, :sensor, :timeframe, :label, :tile
end
