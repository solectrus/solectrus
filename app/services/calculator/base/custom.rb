module Calculator::Base::Custom
  def custom_power_total
    @custom_power_total ||=
      SensorConfig.x.included_custom_sensor_names.sum do |sensor_name|
        safe_power_value(sensor_name)
      end
  end

  def excluded_custom_sensor_names_total
    SensorConfig.x.excluded_custom_sensor_names.sum do |sensor_name|
      safe_power_value(sensor_name)
    end
  end

  def house_power_without_custom
    [house_power - custom_power_total, 0].max
  end

  def house_power_without_custom_percent
    return 0 if house_power.zero?

    house_power_without_custom * 100 / house_power
  end

  def house_power_valid?
    house_power && house_power >= custom_power_total.to_f
  end

  def safe_power_value(sensor_name)
    public_send(sensor_name) || 0
  end

  SensorConfig::CUSTOM_SENSORS.each do |sensor_name|
    define_method(:"#{sensor_name}_percent") do
      total =
        if sensor_name.in?(SensorConfig.x.excluded_custom_sensor_names)
          total_minus
        else
          [house_power, custom_power_total].max
        end
      return 0 if total.zero?

      safe_power_value(sensor_name) * 100 / total
    end
  end
end
