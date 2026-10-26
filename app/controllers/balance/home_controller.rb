class Balance::HomeController < HomePageController
  private

  def page_key = :balance

  def default_sensor_name = Sensor::HomePage.balance_default_sensor
end
