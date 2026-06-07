class Sensor::Chart::GridPower < Sensor::Chart::Base
  # Bars grow in opposite directions (not stacked), so gradient looks good.
  # tooltipAbs: import is negated for the downward bar, but the tooltip should
  # show its magnitude (the label already says "import").
  def style_for_sensor(sensor)
    super.merge(noGradient: false, tooltipAbs: true)
  end

  # Import grows downward (negated), so show the y-axis magnitude in both
  # directions instead of a negative scale.
  def options
    super.deep_merge(scales: { y: { ticks: { callback: 'formatAbs' } } })
  end

  private

  def chart_sensor_names
    %i[grid_export_power grid_import_power]
  end

  # Transform import data to negative values
  def transform_data(data, sensor_name)
    case sensor_name
    when :grid_import_power
      data.map { |value| -value if value } # Make import negative
    else
      data # Export stays positive
    end
  end
end
