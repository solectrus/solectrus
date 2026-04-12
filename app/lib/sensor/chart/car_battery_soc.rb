class Sensor::Chart::CarBatterySoc < Sensor::Chart::MinmaxBase
  def chart_sensor_names
    %i[car_battery_soc]
  end

  private

  # Car battery SOC data arrives at long intervals (15+ minutes),
  # which exceeds the default spanGaps threshold.
  # Bridge all gaps since missing points are due to low sampling rate,
  # not real outages.
  def style_for_sensor(sensor)
    super.merge(spanGaps: true)
  end
end
