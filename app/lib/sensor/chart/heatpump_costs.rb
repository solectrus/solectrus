class Sensor::Chart::HeatpumpCosts < Sensor::Chart::StackedCostBase
  private

  def finance_sensor_name
    :heatpump_costs
  end

  def power_sensor_name
    :heatpump_power
  end
end
