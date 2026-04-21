class Sensor::Chart::CarBatterySoc < Sensor::Chart::MinmaxBase
  def chart_sensor_names
    %i[car_battery_soc]
  end

  private

  # Car battery SOC samples typically arrive at long, irregular intervals
  # (often hours apart). Bridge the resulting gaps so the chart shows a
  # continuous line, since the gaps are low sampling, not real outages.
  def style_for_sensor(sensor)
    super.merge(spanGaps: true)
  end
end
