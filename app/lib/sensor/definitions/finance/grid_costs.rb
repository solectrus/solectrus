class Sensor::Definitions::GridCosts < Sensor::Definitions::FinanceBase
  value

  color background: 'bg-sensor-costs',
        text: 'text-white dark:text-red-200'

  depends_on :grid_import_power

  chart { |timeframe| Sensor::Chart::GridCosts.new(timeframe:) }
  aggregations stored: false, computed: [:sum], meta: %i[sum min max], top10: true
  trend

  def required_prices
    [:electricity]
  end

  def sql_calculation
    'COALESCE(grid_import_power_sum,0) * pb_eur_per_kwh / 1000.0'
  end

  def calculate_with_prices(grid_import_power:, prices:)
    return unless grid_import_power

    electricity_price = prices[:electricity]
    return unless electricity_price

    (grid_import_power || 0) * electricity_price / 1000.0
  end
end
