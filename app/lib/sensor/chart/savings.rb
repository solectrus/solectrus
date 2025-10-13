class Sensor::Chart::Savings < Sensor::Chart::Base
  def chart_sensor_names
    [:savings]
  end

  def permitted?
    ApplicationPolicy.finance_charts?
  end
end
