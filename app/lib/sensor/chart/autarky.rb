class Sensor::Chart::Autarky < Sensor::Chart::Base
  def chart_sensor_names
    %i[autarky]
  end

  def color_class(_sensor)
    'bg-sensor-autarky'
  end

  def meta_aggregation_for_timeframe(_sensor_def)
    :avg
  end
end
