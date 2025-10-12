class Sensor::Definitions::GridRevenue < Sensor::Definitions::FinanceBase
  value

  color hex: '#16a34a',
        bg_classes: 'bg-green-600 dark:bg-green-800',
        text_classes: 'text-green-100 dark:text-green-400'

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
end
