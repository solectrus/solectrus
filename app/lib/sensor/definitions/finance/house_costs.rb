class Sensor::Definitions::HouseCosts < Sensor::Definitions::Base
  value unit: :euro, category: :economic

  depends_on do
    if Setting.opportunity_costs
      %i[house_costs_grid house_costs_pv]
    else
      [:house_costs_grid]
    end
  end

  calculate do |house_costs_grid:, house_costs_pv: nil, **|
    if Setting.opportunity_costs
      house_costs_grid + house_costs_pv if house_costs_grid && house_costs_pv
    else
      house_costs_grid
    end
  end

  aggregations stored: false, computed: [:sum], meta: [:sum]
end
