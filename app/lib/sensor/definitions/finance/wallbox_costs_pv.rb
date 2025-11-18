class Sensor::Definitions::WallboxCostsPv < Sensor::Definitions::FinanceBase
  depends_on :wallbox_power, :wallbox_power_grid

  def required_prices
    [:feed_in]
  end

  def sql_calculation
    # PV power for wallbox consumption = max(wallbox_power - wallbox_power_grid, 0)
    # Similar to house_costs_pv but for wallbox
    'GREATEST(COALESCE(wallbox_power_sum,0) - COALESCE(wallbox_power_grid_sum,0), 0) / 1000.0 * pf_eur_per_kwh'
  end

  def calculate_with_prices(wallbox_power:, wallbox_power_grid:, prices:)
    return unless wallbox_power && wallbox_power_grid

    feed_in_price = prices[:feed_in]
    return unless feed_in_price

    pv_power = [wallbox_power - wallbox_power_grid, 0].max
    pv_power / 1000.0 * feed_in_price
  end
end
