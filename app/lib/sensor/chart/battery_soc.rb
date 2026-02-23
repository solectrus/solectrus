class Sensor::Chart::BatterySoc < Sensor::Chart::MinmaxBase
  def chart_sensor_names
    %i[battery_soc]
  end

  def color_class(_sensor)
    'bg-sensor-battery'
  end
end
