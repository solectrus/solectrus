# What the energy drawn from the grid costs: the imported kWh at the rate per
# kWh of the tariff in force.
#
# One of the two halves of grid_costs, next to grid_base_fee. Its own sensor
# rather than an expression buried in that sum, so the breakdown in the tooltip
# reads the very number the sum is made of.
class Sensor::Definitions::GridEnergyCosts < Sensor::Definitions::FinanceBase
  value

  depends_on :grid_import_power

  aggregations stored: false, computed: [:sum], meta: [:sum]

  def required_prices
    [:electricity]
  end

  def sql_calculation
    'COALESCE(grid_import_power_sum,0) * pb_money_per_kwh / 1000.0'
  end

  def calculate_with_prices(grid_import_power:, prices:)
    electricity_price = prices[:electricity]
    return unless electricity_price && grid_import_power

    grid_import_power * electricity_price / 1000.0
  end
end
