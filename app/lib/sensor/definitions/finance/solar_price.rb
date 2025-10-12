class Sensor::Definitions::SolarPrice < Sensor::Definitions::Base
  value unit: :euro, category: :economic

  depends_on :grid_costs, :grid_revenue

  calculate do |grid_costs:, grid_revenue:, **|
    return unless grid_costs && grid_revenue

    grid_costs - grid_revenue
  end

  aggregations stored: false, computed: [:sum], meta: [:sum]

  # SQL calculation for rankings
  def sql_calculation
    grid_costs = Sensor::Registry[:grid_costs].sql_calculation
    grid_revenue = Sensor::Registry[:grid_revenue].sql_calculation

    "(#{grid_costs}) - (#{grid_revenue})"
  end

  def required_prices
    %i[electricity feed_in]
  end
end
