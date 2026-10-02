class Sensor::Chart::CarMaxRange < Sensor::Chart::Base
  include Sensor::Chart::Concerns::CarNumber

  # car_max_range declares a max_age of 2h, so the base class handles it as a
  # sparse/persistent sensor (leading-edge lookback, gap bridging, stepped
  # rendering) -- see #sparse?.
  def chart_sensor_names
    [Sensor::Cars.sensor_name(:car_max_range, car_number)]
  end

  private

  # car_max_range is a derived value (range at current SOC extrapolated to
  # 100%), so averaging is the only sensible meta aggregation.
  def sql_aggregations_for_sensor(_sensor_name)
    %i[avg avg]
  end
end
