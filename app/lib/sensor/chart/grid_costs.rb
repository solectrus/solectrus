class Sensor::Chart::GridCosts < Sensor::Chart::Base
  def chart_sensor_names
    [:grid_costs]
  end

  def permitted?
    ApplicationPolicy.finance_charts?
  end
end
