class Balance::HomeController < HomePageController
  private

  def page_key = :balance

  def default_sensor_name
    if ApplicationPolicy.power_balance_chart?
      # If the power balance chart is available, we want to show it by default.
      :power_balance
    else
      # Otherwise, we want to show the current production, so we redirect to the inverter_power sensor.
      # But at night this does not make sense, so in this case we redirect to the house_power sensor.
      Sensor::Query::DayLight.active? ? :inverter_power : :house_power
    end
  end
end
