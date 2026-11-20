# The calendar of the insights of a year or of the whole time: on a phone a
# page of its own, which a row pushes into the sheet, on a larger screen a
# part of the list. It belongs to the insights--component controller of the
# list around it (Insights::Component).
class Insights::Heatmap::Component < ViewComponent::Base
  def initialize(data:, sensor:, timeframe:)
    super()
    @data = data
    @sensor = sensor
    @timeframe = timeframe
  end

  attr_reader :data, :sensor, :timeframe
end
