class Sensor::Chart::GridCosts < Sensor::Chart::StackedCostsBase
  # The base fee and the energy costs add up to grid_costs. The fee sits at the
  # bottom, because it is the part that does not move with the consumption.
  def chart_sensor_names
    grid_cost_segments
  end
end
