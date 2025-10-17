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
end
