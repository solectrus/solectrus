class Sensor::Chart::HeatpumpTankTemp < Sensor::Chart::MinmaxBase
  def chart_sensor_names
    %i[heatpump_tank_temp]
  end

  def suggested_min
    20
  end
end
