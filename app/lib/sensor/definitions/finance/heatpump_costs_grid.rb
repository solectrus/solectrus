class Sensor::Definitions::HeatpumpCostsGrid < Sensor::Definitions::FinanceBase
  depends_on :heatpump_power_grid

  def required_prices
    [:electricity]
  end

  def sql_calculation
    'heatpump_power_grid_sum * pb_eur_per_kwh / 1000.0'
  end

  def calculate_with_prices(heatpump_power_grid:, prices:)
    return unless heatpump_power_grid

    electricity_price = prices[:electricity]
    return unless electricity_price

    heatpump_power_grid * electricity_price / 1000.0
  end
end
