class Sensor::Chart::TotalCosts < Sensor::Chart::StackedCostsBase
  # total_costs is the grid costs plus the opportunity costs, and the grid
  # costs carry their own split. The segments are the same parts that
  # ConsumeDetails::Component breaks the sum into, in the same order: the grid
  # side first, the PV side on top.
  def chart_sensor_names
    grid_cost_segments + [:opportunity_costs]
  end
end
