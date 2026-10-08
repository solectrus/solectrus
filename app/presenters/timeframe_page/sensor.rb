# The addresses of a page with a timeframe, for the timeframe navigation
# (Timeframe::Component) and the timeframe select (TimeframeSelect::Component).
# This is the sensor page of a section.
class TimeframePage::Sensor
  include Rails.application.routes.url_helpers

  # `params` are the parameters that each link of the page keeps, like the
  # selected car (see ApplicationController#selection_params). The route has
  # a place for each of them in front of the timeframe.
  def initialize(namespace:, sensor_name:, params: {})
    @namespace = namespace
    @sensor_name = sensor_name
    @params = params
  end

  # The page in the given timeframe
  def path(timeframe)
    url_for(controller: "/#{@namespace}/home", action: 'index', sensor_name: @sensor_name, timeframe:, **@params, only_path: true)
  end

  # The timeframe select adds the timeframe to `base_url` in the browser
  def base_url
    url_for(controller: "/#{@namespace}/home", action: 'index', sensor_name: @sensor_name, **@params, only_path: true)
  end

  # Forward from today into the forecast
  def forecast? = Sensor::Config.exists?(:inverter_power_forecast)

  def hours? = Sensor::HomePage.hours?(@namespace.to_sym)
end
