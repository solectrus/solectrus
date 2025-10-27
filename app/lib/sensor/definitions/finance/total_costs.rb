class Sensor::Definitions::TotalCosts < Sensor::Definitions::FinanceBase
  color hex: '#ef4444',
        bg_classes: 'bg-red-500 dark:bg-red-400',
        text_classes: 'text-red-100 dark:text-red-400'

  depends_on do
    Setting.opportunity_costs ? %i[grid_costs opportunity_costs] : [:grid_costs]
  end
  trend

  calculate do |grid_costs:, opportunity_costs: nil, **|
    if Setting.opportunity_costs
      grid_costs + opportunity_costs if grid_costs && opportunity_costs
    else
      grid_costs
    end
  end

  aggregations stored: false,
               computed: [:sum],
               meta: [:sum],
               top10: -> { Setting.opportunity_costs }

  chart { |timeframe| Sensor::Chart::TotalCosts.new(timeframe:) }

  def chart_enabled?
    # Without opportunity costs, total_costs is identical to grid_costs
    Setting.opportunity_costs
  end

  def required_prices
    Setting.opportunity_costs ? %i[electricity feed_in] : [:electricity]
  end

  def sql_calculation
    grid_costs_calc = Sensor::Registry[:grid_costs].sql_calculation

    if Setting.opportunity_costs
      opportunity_costs_calc =
        Sensor::Registry[:opportunity_costs].sql_calculation

      "(#{grid_costs_calc}) + (#{opportunity_costs_calc})"
    else
      grid_costs_calc
    end
  end

  def calculate_with_prices(grid_costs: nil, opportunity_costs: nil, **)
    if Setting.opportunity_costs
      grid_costs + opportunity_costs if grid_costs && opportunity_costs
    else
      grid_costs
    end
  end
end
