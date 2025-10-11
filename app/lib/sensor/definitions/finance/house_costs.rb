class Sensor::Definitions::HouseCosts < Sensor::Definitions::Base
  value unit: :euro, category: :economic

  depends_on :house_costs_grid, :house_costs_pv

  calculate do |house_costs_grid:, house_costs_pv:, **|
    return unless house_costs_grid && house_costs_pv

    house_costs_grid + house_costs_pv
  end

  aggregations stored: false, computed: [:sum], meta: [:sum]
end
