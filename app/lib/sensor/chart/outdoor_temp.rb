class Sensor::Chart::OutdoorTemp < Sensor::Chart::MinmaxBase
  def chart_sensor_names
    names = %i[outdoor_temp]
    names << :outdoor_temp_forecast if timeframe.today?

    Sensor::Config.sensors.filter_map do |sensor|
      sensor.name if sensor.name.in?(names)
    end
  end

  private

  def transform_data(data_values, sensor_name)
    return super unless sensor_name == :outdoor_temp_forecast

    # Set past values to nil (keeps timestamps but hides line in past)
    now = Time.current
    points =
      series.public_send(sensor_name, *aggregations_for_sensor(sensor_name))

    points.map do |time_key, value|
      normalize_timestamp(time_key) > now ? value : nil
    end
  end

  def style_for_sensor(sensor)
    if sensor.name == :outdoor_temp_forecast
      super.merge(fill: false, borderDash: [2, 3])
    else
      super
    end
  end
end
