class Sensor::Chart::CarBatterySoc < Sensor::Chart::MinmaxBase
  # car_battery_soc declares a max_age of 2h (its readings arrive at long,
  # irregular intervals and persist between samples), so it is handled as a
  # sparse/persistent sensor by the base class -- see #sparse?. No chart-level
  # special-casing needed beyond naming the sensor.
  def chart_sensor_names
    %i[car_battery_soc]
  end
end
