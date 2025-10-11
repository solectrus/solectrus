class Sensor::Definitions::HeatpumpCostsPv < Sensor::Definitions::FinanceBase
  depends_on :heatpump_power, :heatpump_power_grid

  def required_prices
    [:feed_in]
  end

  def sql_calculation
    'GREATEST(COALESCE(heatpump_power_sum,0) - COALESCE(heatpump_power_grid_sum,0), 0) / 1000.0 * pf_eur_per_kwh'
  end
end
