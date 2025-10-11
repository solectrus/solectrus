class Sensor::Definitions::BatterySavings < Sensor::Definitions::FinanceBase
  depends_on :battery_discharging_power, :battery_charging_power

  def required_prices
    %i[electricity feed_in]
  end

  def sql_calculation
    # Savings from battery discharge (what you save by not buying from grid)
    # minus lost revenue from charging (what you lose by not feeding into grid)
    '(COALESCE(battery_discharging_power_sum, 0) * pb_eur_per_kwh - COALESCE(battery_charging_power_sum, 0) * pf_eur_per_kwh) / 1000.0'
  end
end
