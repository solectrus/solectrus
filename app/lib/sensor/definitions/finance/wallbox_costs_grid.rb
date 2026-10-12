class Sensor::Definitions::WallboxCostsGrid < Sensor::Definitions::FinanceBase
  include Sensor::Definitions::ConsumerGridCosts

  def power_sensor
    :wallbox_power_grid
  end
end
