class Sensor::Definitions::WallboxCostsGrid < Sensor::Definitions::FinanceBase
  depends_on :wallbox_power_grid

  def required_prices
    [:electricity]
  end

  def sql_calculation
    'wallbox_power_grid_sum * pb_eur_per_kwh / 1000.0'
  end
end
