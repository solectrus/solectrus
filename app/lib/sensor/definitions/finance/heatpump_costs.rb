class Sensor::Definitions::HeatpumpCosts < Sensor::Definitions::Base
  color background: 'bg-sensor-costs',
        text: 'text-white dark:text-red-200'

  value unit: :euro, category: :economic

  depends_on %i[heatpump_costs_grid heatpump_costs_pv]
  trend

  chart { |timeframe| Sensor::Chart::HeatpumpCosts.new(timeframe:) }

  calculate do |heatpump_costs_grid:, heatpump_costs_pv:, **|
    if heatpump_costs_grid && heatpump_costs_pv
      heatpump_costs_grid + heatpump_costs_pv
    end
  end

  aggregations stored: false, computed: [:sum], meta: [:sum]
end
