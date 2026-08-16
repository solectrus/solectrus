class House::HomeController < HomePageController
  private

  def page_key = :house

  def default_sensor_name = :house_power

  # The house page has no forecast, so a future timeframe goes back to now.
  def future_path = path_for(sensor_name)
end
