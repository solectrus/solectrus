class Heatpump::HomeController < HomePageController
  private

  def page_key = :heatpump

  def default_sensor_name = :heatpump_heating_power

  # The heat pump page has no forecast, so a future timeframe goes back to now.
  def future_path = path_for(sensor_name)
end
