module SensorPathHelper
  # The chart of a sensor lives on the home page that shows it, so its path
  # carries that page (/house/washing_machine/2026). This helper is the only
  # place that has to know. Everywhere else asks for a path and gets one that
  # the target page really answers.
  def sensor_home_path(sensor_name, timeframe:)
    public_send(sensor_path_helpers[sensor_name], sensor_name:, timeframe:)
  end

  private

  # A heatmap asks once per day and a Top10 table once per row, always for the
  # same sensor. Finding the page reads the sensor list of every page, so the
  # answer stays for the rest of the render.
  def sensor_path_helpers
    @sensor_path_helpers ||=
      Hash.new do |cache, sensor_name|
        cache[sensor_name] = :"#{Sensor::HomePage.page_for(sensor_name)}_home_path"
      end
  end
end
