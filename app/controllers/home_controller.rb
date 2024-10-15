class HomeController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation

  def index
    unless sensor && timeframe
      redirect_to(default_path)
      return
    end

    @missing_days = Summary.missing_days(timeframe) if summaries_missing?
  end

  private

  def summaries_missing?
    # For "now" we don't need summaries at all
    return false if timeframe.now?

    # For single days we need the summary to be present, but we don't need to wait for it.
    # It can created on the fly in the StatsController, if missing.
    return false if timeframe.day?

    # If the summary is already present, we don't need to wait for it.
    return false if Summary.completed?(timeframe)

    # Timeframe is longer (week / month / year / all) and summaries are missing.
    true
  end

  def default_path
    root_path(sensor: sensor || redirect_sensor, timeframe: 'now')
  end

  # By default we want to show the current production, so we redirect to the inverter_power sensor.
  # But at night this does not make sense, so in this case we redirect to the house_power sensor.
  def redirect_sensor
    DayLight.active? ? :inverter_power : :house_power
  end
end
