class Sensor::Definitions::TraditionalCosts < Sensor::Definitions::FinanceBase
  depends_on do
    [
      :house_power,
      (:heatpump_power if Sensor::Config.configured?(:heatpump_power)),
      (:wallbox_power if Sensor::Config.configured?(:wallbox_power)),
    ].compact
  end

  def required_prices
    [:electricity]
  end

  def sql_calculation
    parts = dependencies.map { |dep| "COALESCE(#{dep}_sum,0)" }

    "(#{parts.join(' + ')}) * pb_eur_per_kwh / 1000.0"
  end

  def calculate_with_prices(
    house_power:,
    heatpump_power:,
    wallbox_power:,
    prices:
  )
    electricity_price = prices[:electricity]
    return unless electricity_price

    # Build hash from parameters to match dependencies
    values = { house_power:, heatpump_power:, wallbox_power: }

    # Sum all power values from dependencies
    total_power = dependencies.sum { |dep| values[dep] || 0 }

    total_power * electricity_price / 1000.0
  end
end
