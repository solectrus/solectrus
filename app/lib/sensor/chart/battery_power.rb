class Sensor::Chart::BatteryPower < Sensor::Chart::Base
  # Bars grow in opposite directions (not stacked), so gradient looks good.
  # tooltipAbs: discharging is negated for the downward bar, but the tooltip
  # should show its magnitude (the label already says "discharge").
  def style_for_sensor(sensor)
    super.merge(noGradient: false, tooltipAbs: true)
  end

  # Discharging grows downward (negated), so show the y-axis magnitude in
  # both directions instead of a negative scale.
  def options
    super.deep_merge(scales: { y: { ticks: { callback: 'formatAbs' } } })
  end

  private

  def chart_sensor_names
    %i[battery_charging_power battery_discharging_power]
  end

  # Transform import data to negative values
  def transform_data(data, sensor_name)
    case sensor_name
    when :battery_discharging_power
      data.map { |value| -value if value } # Make discharging negative
    else
      data # Charging stays positive
    end
  end
end
