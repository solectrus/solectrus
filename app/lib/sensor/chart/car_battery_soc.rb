class Sensor::Chart::CarBatterySoc < Sensor::Chart::MinmaxBase
  include Sensor::Chart::Concerns::CarNumber

  # car_battery_soc declares a max_age of 2h (its readings arrive at long,
  # irregular intervals and persist between samples), so it is handled as a
  # sparse/persistent sensor by the base class -- see #sparse?. No chart-level
  # special-casing needed beyond naming the sensor.
  def chart_sensor_names
    [Sensor::Cars.sensor_name(:car_battery_soc, car_number)]
  end
end
