class Balance::HomeController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation
  include SummaryChecker

  def index
    unless sensor && timeframe
      redirect_to(default_path)
      return
    end

    load_missing_or_stale_summary_days(timeframe)
  end

  private

  helper_method def sensors
    [
      *DEFAULT_SENSORS,
      *SensorConfig.x.excluded_custom_sensor_names,
      *inverter_sensor_names,
    ]
  end

  DEFAULT_SENSORS = %i[
    grid_power
    house_power
    heatpump_power
    wallbox_power
    battery_power
    battery_soc
    car_battery_soc
    case_temp
    autarky
    self_consumption
    co2_reduction
  ].freeze
  private_constant :DEFAULT_SENSORS

  def inverter_sensor_names
    return [:inverter_power] unless multi_inverter_enabled?

    if Setting.inverter_as_total
      [:inverter_power]
    else
      ([:inverter_power] + SensorConfig.x.inverter_sensor_names).uniq
    end
  end

  def multi_inverter_enabled?
    SensorConfig.x.multi_inverter? && ApplicationPolicy.multi_inverter?
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
