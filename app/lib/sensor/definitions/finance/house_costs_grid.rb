class Sensor::Definitions::HouseCostsGrid < Sensor::Definitions::FinanceBase
  depends_on :house_power_grid

  def required_prices
    [:electricity]
  end

  def sql_calculation
    'house_power_grid_sum * pb_eur_per_kwh / 1000.0'
  end
end
