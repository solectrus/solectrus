# The remaining range of the car. The range of a day depends on the charge, so
# the chart draws a day at most. car_max_range shows the longer history.
class Sensor::Chart::CarRange < Sensor::Chart::Base
  include Sensor::Chart::Concerns::OneCar

  def self.supports?(timeframe)
    timeframe.short?
  end

  # car_range is a state, so the base class holds its value between two
  # readings -- see #holds_value?.
  def chart_sensor_names
    sensor_names_of(:car_range)
  end
end
