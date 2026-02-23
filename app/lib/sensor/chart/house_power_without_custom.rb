class Sensor::Chart::HousePowerWithoutCustom < Sensor::Chart::PowerSplitterBase
  def color_class(_sensor)
    'bg-sensor-house'
  end

  private

  def base_sensor_name
    :house_power_without_custom
  end

  def grid_sensor_name
    :house_power_without_custom_grid
  end

  def pv_sensor_name
    :house_power_without_custom_pv
  end
end
