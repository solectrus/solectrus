class Sensor::Definitions::HouseCostsGrid < Sensor::Definitions::FinanceBase
  include Sensor::Definitions::ConsumerGridCosts

  def power_sensor
    :house_power_grid
  end

  # The house carries the whole base fee: the household is what the grid
  # connection is for, and the fee is due without a heat pump or a wallbox.
  #
  # Only where grid_base_fee exists, which is where the grid meter is. Without
  # it grid_costs has no fee either, and the per-consumer costs would no longer
  # add up to it.
  def carries_base_fee?
    Sensor::Config.exists?(:grid_base_fee)
  end
end
