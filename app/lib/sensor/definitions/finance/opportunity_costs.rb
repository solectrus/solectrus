class Sensor::Definitions::OpportunityCosts < Sensor::Definitions::FinanceBase
  depends_on :inverter_power, :grid_export_power

  def required_prices
    [:feed_in]
  end

  def sql_calculation
    # Opportunity costs = self-consumed energy * feed-in price
    # Self-consumed = inverter_power - grid_export_power
    # Only positive values (when there is actual self-consumption)
    'GREATEST((COALESCE(inverter_power_sum,0) - COALESCE(grid_export_power_sum,0)), 0) * pf_eur_per_kwh / 1000.0'
  end
end
