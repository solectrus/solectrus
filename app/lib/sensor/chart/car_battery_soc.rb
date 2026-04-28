class Sensor::Chart::CarBatterySoc < Sensor::Chart::MinmaxBase
  def chart_sensor_names
    %i[car_battery_soc]
  end

  private

  # Car battery SOC samples arrive at long, irregular intervals (15+ min,
  # often hours). SOC is persistent between samples, so forward-fill empty
  # aggregation buckets with the last known value. This prevents gaps on
  # the leading and trailing edges of the NOW window where only a handful
  # of samples fall.
  def fill_missing_with_previous?
    true
  end

  # Bridge gaps unconditionally - SOC samples can be hours apart, far
  # beyond the global 15-min span threshold from the base class.
  def style_for_sensor(sensor)
    super.merge(spanGaps: true)
  end
end
