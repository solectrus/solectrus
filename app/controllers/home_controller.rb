class HomeController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation

  def index
    redirect_to(default_path) unless sensor && timeframe
  end

  private

  def default_path
    root_path(sensor: sensor || redirect_sensor, timeframe: 'now')
  end

  # By default we want to show the current production, so we redirect to the inverter_power sensor.
  # But at night this does not make sense, so in this case we redirect to the house_power sensor.
  def redirect_sensor
    DayLight.active? ? :inverter_power : :house_power
  end
end
