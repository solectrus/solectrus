class Sensor::Definitions::TotalCosts < Sensor::Definitions::FinanceBase
  color background: 'bg-red-700 dark:bg-red-800/80',
        text: 'text-white dark:text-red-200'

  depends_on %i[grid_costs opportunity_costs]
  trend

  calculate do |grid_costs:, opportunity_costs:, **|
    grid_costs + opportunity_costs if grid_costs && opportunity_costs
  end

  aggregations stored: false, computed: [:sum], meta: %i[sum min max], top10: true

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
