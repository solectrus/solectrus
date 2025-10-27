class Sensor::Definitions::HouseCostsGrid < Sensor::Definitions::FinanceBase
  depends_on :house_power_grid

  def required_prices
    [:electricity]
  end

  def sql_calculation
    'house_power_grid_sum * pb_eur_per_kwh / 1000.0'
  end

  def calculate_with_prices(house_power_grid:, prices:)
    return unless house_power_grid

    electricity_price = prices[:electricity]
    return unless electricity_price

    house_power_grid * electricity_price / 1000.0
  end
end
