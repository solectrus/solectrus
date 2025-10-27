class Sensor::Definitions::BatteryChargingCosts < Sensor::Definitions::FinanceBase
  depends_on :battery_charging_power_grid

  def required_prices
    [:electricity]
  end

  def sql_calculation
    'battery_charging_power_grid_sum * pb_eur_per_kwh / 1000.0'
  end

  def calculate_with_prices(battery_charging_power_grid:, prices:)
    electricity_price = prices[:electricity]
    return unless electricity_price

    return unless battery_charging_power_grid

    battery_charging_power_grid * electricity_price / 1000.0
  end
end
