class Sensor::Definitions::WallboxCostsGrid < Sensor::Definitions::FinanceBase
  depends_on :wallbox_power_grid

  def required_prices
    [:electricity]
  end

  def sql_calculation
    'wallbox_power_grid_sum * pb_eur_per_kwh / 1000.0'
  end

  def calculate_with_prices(wallbox_power_grid:, prices:)
    return unless wallbox_power_grid

    electricity_price = prices[:electricity]
    return unless electricity_price

    wallbox_power_grid * electricity_price / 1000.0
  end
end
