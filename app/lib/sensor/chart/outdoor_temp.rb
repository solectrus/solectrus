class Sensor::Chart::OutdoorTemp < Sensor::Chart::MinmaxBase
  def chart_sensor_names
    %i[outdoor_temp]
  end
end
