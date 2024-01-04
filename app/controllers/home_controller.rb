class HomeController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation

  def index
    redirect_to(default_path) unless field && timeframe
  end

  private

  def default_path
    root_path(field: field || redirect_field, timeframe: 'now')
  end

  # By default we want to show the current production, so we redirect to the inverter_power field.
  # But at night this does not make sense, so in this case we redirect to the house_power field.
  def redirect_field
    DayLight.active? ? 'inverter_power' : 'house_power'
  end
end
