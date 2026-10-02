# The remaining range of the car. The range of a day depends on the charge, so
# the chart draws a day at most. car_max_range shows the longer history.
class Sensor::Chart::CarRange < Sensor::Chart::Base
  include Sensor::Chart::Concerns::CarNumber

  def self.supports?(timeframe)
    timeframe.short?
  end

  # car_range declares a max_age of 2h, so the base class handles it as a
  # sparse/persistent sensor -- see #sparse?.
  def chart_sensor_names
    [Sensor::Cars.sensor_name(:car_range, car_number)]
  end

  private

  def build_data
    return unless supported?

    super
  end
end
