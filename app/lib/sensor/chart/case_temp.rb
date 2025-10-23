class Sensor::Chart::CaseTemp < Sensor::Chart::MinmaxBase
  def chart_sensor_names
    %i[case_temp]
  end

  def suggested_min
    10
  end
end
