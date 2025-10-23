class Sensor::Chart::CarBatterySoc < Sensor::Chart::MinmaxBase
  def chart_sensor_names
    %i[car_battery_soc]
  end
end
