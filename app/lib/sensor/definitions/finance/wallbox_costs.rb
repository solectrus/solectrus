class Sensor::Definitions::WallboxCosts < Sensor::Definitions::Base
  value unit: :euro, category: :economic

  depends_on do
    if Setting.opportunity_costs
      %i[wallbox_costs_grid wallbox_costs_pv]
    else
      [:wallbox_costs_grid]
    end
  end

  calculate do |wallbox_costs_grid:, wallbox_costs_pv: nil, **|
    if Setting.opportunity_costs
      if wallbox_costs_grid && wallbox_costs_pv
        wallbox_costs_grid + wallbox_costs_pv
      end
    else
      wallbox_costs_grid
    end
  end

  aggregations stored: false, computed: [:sum], meta: [:sum]
end
