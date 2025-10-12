class Sensor::Definitions::BatteryChargingCosts < Sensor::Definitions::FinanceBase
  depends_on :battery_charging_power_grid

  def required_prices
    [:electricity]
  end

  def sql_calculation
    'battery_charging_power_grid_sum * pb_eur_per_kwh / 1000.0'
  end
end
