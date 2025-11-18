class Sensor::Chart::WallboxPower < Sensor::Chart::PowerSplitterBase
  private

  def base_sensor_name
    :wallbox_power
  end

  def grid_sensor_name
    :wallbox_power_grid
  end

  def pv_sensor_name
    :wallbox_power_pv
  end
end
