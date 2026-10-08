class Sensor::Definitions::TraditionalCosts < Sensor::Definitions::FinanceBase
  # What the same consumption would have cost without PV, so this must cover the
  # complete consumption -- including custom consumers excluded from house_power
  # (they are subtracted from house_power, in the live value as well as in the
  # stored summary). Reuse total_consumption's dependencies to stay in sync.
  depends_on { Sensor::Registry[:total_consumption].dependencies }

  def required_prices
    [:electricity]
  end

  # Without PV the same base fee would still be on the bill, so it belongs in
  # this comparison. It cancels out against grid_costs in savings, which keeps
  # the base fee out of the savings and out of the amortization.
  def carries_base_fee?
    true
  end

  def sql_calculation
    parts = dependencies.map { |dep| "COALESCE(#{dep}_sum,0)" }

    with_base_fee_sql("(#{parts.join(' + ')}) * pb_money_per_kwh / 1000.0")
  end

  # The fee itself is added by Sensor::Definitions::FinanceBase#with_base_fee.
  def calculate_with_prices(prices:, **values)
    electricity_price = prices[:electricity]
    return unless electricity_price

    total_power = dependencies.sum { |dep| values[dep] || 0 }

    total_power * electricity_price / 1000.0
  end
end
