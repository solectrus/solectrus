class Sensor::Chart::HeatpumpPower < Sensor::Chart::PowerSplitterBase
  private

  def base_sensor_name
    :heatpump_power
  end

  def grid_sensor_name
    :heatpump_power_grid
  end

  def pv_sensor_name
    :heatpump_power_pv
  end
end
