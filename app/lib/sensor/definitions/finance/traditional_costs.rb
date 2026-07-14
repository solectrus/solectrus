class Sensor::Definitions::TraditionalCosts < Sensor::Definitions::FinanceBase
  # What the same consumption would have cost without PV, so this must cover the
  # complete consumption -- including custom consumers excluded from house_power
  # (they are subtracted from house_power, in the live value as well as in the
  # stored summary). Reuse total_consumption's dependencies to stay in sync.
  depends_on { Sensor::Registry[:total_consumption].dependencies }

  def required_prices
    [:electricity]
  end

  def sql_calculation
    parts = dependencies.map { |dep| "COALESCE(#{dep}_sum,0)" }

    "(#{parts.join(' + ')}) * pb_money_per_kwh / 1000.0"
  end

  def calculate_with_prices(prices:, **values)
    electricity_price = prices[:electricity]
    return unless electricity_price

    total_power = dependencies.sum { |dep| values[dep] || 0 }

    total_power * electricity_price / 1000.0
  end
end
