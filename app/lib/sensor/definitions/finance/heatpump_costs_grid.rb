class Sensor::Definitions::HeatpumpCostsGrid < Sensor::Definitions::FinanceBase
  include Sensor::Definitions::ConsumerGridCosts

  def power_sensor
    :heatpump_power_grid
  end
end
