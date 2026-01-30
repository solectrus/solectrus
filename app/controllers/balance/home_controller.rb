class Balance::HomeController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation
  include SummaryChecker

  def index
    unless sensor_name && timeframe
      redirect_to(default_path)
      return
    end

    if timeframe.future? && Sensor::Config.exists?(:inverter_power_forecast)
      redirect_to forecast_path
      return
    end

    load_missing_or_stale_summary_days(timeframe)
  end

  private

  def default_path
    balance_home_path(
      sensor_name: sensor_name || redirect_sensor,
      timeframe: 'now',
    )
  end

  def redirect_sensor
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
