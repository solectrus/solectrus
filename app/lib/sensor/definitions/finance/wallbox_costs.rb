class Sensor::Definitions::WallboxCosts < Sensor::Definitions::Base
  value unit: :euro, category: :economic

  depends_on :wallbox_costs_grid, :wallbox_costs_pv

  calculate do |wallbox_costs_grid:, wallbox_costs_pv:, **|
    return unless wallbox_costs_grid && wallbox_costs_pv

    wallbox_costs_grid + wallbox_costs_pv
  end

  aggregations stored: false, computed: [:sum], meta: [:sum]
end
