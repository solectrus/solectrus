class Sensor::Chart::TotalCosts < Sensor::Chart::Base
  def chart_sensor_names
    [:total_costs]
  end

  def permitted?
    ApplicationPolicy.finance_charts?
  end
end
