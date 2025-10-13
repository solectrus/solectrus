class Sensor::Chart::GridRevenue < Sensor::Chart::Base
  def chart_sensor_names
    [:grid_revenue]
  end

  def permitted?
    ApplicationPolicy.finance_charts?
  end
end
