class Sensor::Definitions::GridCosts < Sensor::Definitions::FinanceBase
  value

  color hex: '#ef4444',
        bg_classes: 'bg-red-700 dark:bg-red-800/80',
        text_classes: 'text-red-700 dark:text-red-400'

  depends_on :grid_import_power

  chart { |timeframe| Sensor::Chart::GridCosts.new(timeframe:) }
  aggregations stored: false, computed: [:sum], meta: [:sum], top10: true
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
