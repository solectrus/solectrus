class Sensor::Definitions::TotalCosts < Sensor::Definitions::FinanceBase
  color hex: '#ef4444',
        bg_classes: 'bg-red-500 dark:bg-red-400',
        text_classes: 'text-red-100 dark:text-red-400'

  depends_on %i[grid_costs opportunity_costs]
  trend

  calculate do |grid_costs:, opportunity_costs:, **|
    grid_costs + opportunity_costs if grid_costs && opportunity_costs
  end

  aggregations stored: false, computed: [:sum], meta: [:sum], top10: true

  chart { |timeframe| Sensor::Chart::TotalCosts.new(timeframe:) }

  def chart_enabled?
    true
  end

  def required_prices
    %i[electricity feed_in]
  end

  def sql_calculation
    grid_costs_calc = Sensor::Registry[:grid_costs].sql_calculation
    opportunity_costs_calc =
      Sensor::Registry[:opportunity_costs].sql_calculation

    "(#{grid_costs_calc}) + (#{opportunity_costs_calc})"
  end

  def calculate_with_prices(grid_costs:, opportunity_costs:, **)
    grid_costs + opportunity_costs if grid_costs && opportunity_costs
  end
end
