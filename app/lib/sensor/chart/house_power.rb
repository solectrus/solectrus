class Sensor::Chart::HousePower < Sensor::Chart::PowerSplitterBase
  private

  def base_sensor_name
    :house_power
  end

  def grid_sensor_name
    :house_power_grid
  end

  def pv_sensor_name
    :house_power_pv
  end
end
