class Sensor::Definitions::HeatpumpCosts < Sensor::Definitions::Base
  value unit: :euro, category: :economic

  depends_on :heatpump_costs_grid, :heatpump_costs_pv

  calculate do |heatpump_costs_grid:, heatpump_costs_pv:, **|
    return unless heatpump_costs_grid && heatpump_costs_pv

    heatpump_costs_grid + heatpump_costs_pv
  end

  aggregations stored: false, computed: [:sum], meta: [:sum]
end
