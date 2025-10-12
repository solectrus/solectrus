class Sensor::Definitions::HeatpumpCostsGrid < Sensor::Definitions::FinanceBase
  depends_on :heatpump_power_grid

  def required_prices
    [:electricity]
  end

  def sql_calculation
    'heatpump_power_grid_sum * pb_eur_per_kwh / 1000.0'
  end
end
