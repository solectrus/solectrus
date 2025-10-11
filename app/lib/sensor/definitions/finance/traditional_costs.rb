class Sensor::Definitions::TraditionalCosts < Sensor::Definitions::FinanceBase
  depends_on :house_power, :heatpump_power, :wallbox_power

  def required_prices
    [:electricity]
  end

  def sql_calculation
    '(COALESCE(house_power_sum,0) + COALESCE(heatpump_power_sum,0) + COALESCE(wallbox_power_sum,0)) * pb_eur_per_kwh / 1000.0'
  end
end
