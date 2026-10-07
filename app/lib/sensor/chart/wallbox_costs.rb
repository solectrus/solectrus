# The cost of the wallbox for now and a day on the car page (see
# Sensor::Definitions::CarChargingCosts)
class Sensor::Chart::WallboxCosts < Sensor::Chart::StackedCostBase
  # The cost needs the split of the power splitter into PV and grid
  def supported?
    super && Sensor::Config.exists?(:wallbox_costs)
  end

  # Stacked from the bottom up: PV, grid, like the columns of the sessions
  def chart_sensor_names
    super.reverse
  end

  private

  def finance_sensor_name
    :wallbox_costs
  end

  def power_sensor_name
    :wallbox_power
  end
end
