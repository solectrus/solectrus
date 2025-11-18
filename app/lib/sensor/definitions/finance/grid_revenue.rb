class Sensor::Definitions::GridRevenue < Sensor::Definitions::FinanceBase
  value

  color hex: '#16a34a',
        bg_classes: 'bg-green-700 dark:bg-green-800/80',
        text_classes: 'text-green-700 dark:text-green-400'

  depends_on :grid_export_power
  trend more_is_better: true

  chart { |timeframe| Sensor::Chart::GridRevenue.new(timeframe:) }
  aggregations stored: false, computed: [:sum], top10: true

  def required_prices
    [:feed_in]
  end

  def sql_calculation
    'COALESCE(grid_export_power_sum,0) * pf_eur_per_kwh / 1000.0'
  end

  def calculate_with_prices(grid_export_power:, prices:)
    return unless grid_export_power

    feed_in_price = prices[:feed_in]
    return unless feed_in_price

    (grid_export_power || 0) * feed_in_price / 1000.0
  end
end
