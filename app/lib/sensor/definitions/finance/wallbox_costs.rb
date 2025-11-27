class Sensor::Definitions::WallboxCosts < Sensor::Definitions::Base
  value unit: :euro, category: :economic

  depends_on %i[wallbox_costs_grid wallbox_costs_pv]

  calculate do |wallbox_costs_grid:, wallbox_costs_pv:, **|
    if wallbox_costs_grid && wallbox_costs_pv
      wallbox_costs_grid + wallbox_costs_pv
    end
  end

  aggregations stored: false, computed: [:sum], meta: [:sum]
end
