class Sensor::Chart::BatterySoc < Sensor::Chart::MinmaxBase
  def chart_sensor_names
    %i[battery_soc]
  end
end
