class Sensor::Definitions::HeatpumpCosts < Sensor::Definitions::Base
  value unit: :euro, category: :economic

  depends_on do
    if Setting.opportunity_costs
      %i[heatpump_costs_grid heatpump_costs_pv]
    else
      [:heatpump_costs_grid]
    end
  end

  calculate do |heatpump_costs_grid:, heatpump_costs_pv: nil, **|
    if Setting.opportunity_costs
      if heatpump_costs_grid && heatpump_costs_pv
        heatpump_costs_grid + heatpump_costs_pv
      end
    else
      heatpump_costs_grid
    end
  end

  aggregations stored: false, computed: [:sum], meta: [:sum]
end
