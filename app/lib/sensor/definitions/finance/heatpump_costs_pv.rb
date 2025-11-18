class Sensor::Definitions::HeatpumpCostsPv < Sensor::Definitions::FinanceBase
  depends_on :heatpump_power, :heatpump_power_grid

  def required_prices
    [:feed_in]
  end

  def sql_calculation
    'GREATEST(COALESCE(heatpump_power_sum,0) - COALESCE(heatpump_power_grid_sum,0), 0) / 1000.0 * pf_eur_per_kwh'
  end

  def calculate_with_prices(heatpump_power:, heatpump_power_grid:, prices:)
    return unless heatpump_power && heatpump_power_grid

    feed_in_price = prices[:feed_in]
    return unless feed_in_price

    pv_power = [heatpump_power - heatpump_power_grid, 0].max
    pv_power / 1000.0 * feed_in_price
  end
end
