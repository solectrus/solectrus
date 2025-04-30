class Balance::ChartsController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation

  def index
    render formats: :turbo_stream
  end

  private

  def calculator_range
    Calculator::Range.new(
      timeframe,
      calculations: [
        Queries::Calculation.new(:inverter_power, :sum, :sum),
        Queries::Calculation.new(:inverter_power_forecast, :sum, :sum),
        *SensorConfig::CUSTOM_INVERTER_SENSORS.map do |sensor_name|
          Queries::Calculation.new(sensor_name, :sum, :sum)
        end,
      ],
    )
  end

  helper_method def chart_sensors
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
      SensorConfig.x.existing_custom_inverter_sensor_names
    end
  end

  def multi_inverter_enabled?
    SensorConfig.x.multi_inverter? && ApplicationPolicy.multi_inverter?
  end
end
