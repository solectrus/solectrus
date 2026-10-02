class Sensor::Chart::WallboxCosts < Sensor::Chart::StackedCostBase
  private

  def finance_sensor_name
    :wallbox_costs
  end

  def power_sensor_name
    :wallbox_power
  end
end
