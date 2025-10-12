class Sensor::Definitions::HouseCostsPv < Sensor::Definitions::FinanceBase
  depends_on :house_power, :house_power_grid

  def required_prices
    [:feed_in]
  end

  def sql_calculation
    # PV power for house consumption = max(house_power - house_power_grid, 0)
    # Based on CLAUDE.md Example 7, line 484-486
    'GREATEST(COALESCE(house_power_sum,0) - COALESCE(house_power_grid_sum,0), 0) / 1000.0 * pf_eur_per_kwh'
  end
end
