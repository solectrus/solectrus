class Sensor::Definitions::GridBalance < Sensor::Definitions::Base
  value unit: :euro, category: :economic

  depends_on :grid_revenue, :grid_costs

  calculate do |grid_revenue:, grid_costs:, **|
    grid_revenue.to_f - grid_costs.to_f
  end

  aggregations stored: false, computed: [:sum]
end
