class Sensor::Definitions::HeatpumpCosts < Sensor::Definitions::Base
  value unit: :euro, category: :economic

  depends_on %i[heatpump_costs_grid heatpump_costs_pv]

  calculate do |heatpump_costs_grid:, heatpump_costs_pv:, **|
    if heatpump_costs_grid && heatpump_costs_pv
      heatpump_costs_grid + heatpump_costs_pv
    end
  end

  aggregations stored: false, computed: [:sum], meta: [:sum]
end
