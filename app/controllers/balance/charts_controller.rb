class Balance::ChartsController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation

  def index
    if turbo_frame_request?
      # Request comes from a single TurboFrame, but we want to update multiple other frames, too
      render formats: :turbo_stream
    else
      # Fallback
      redirect_to balance_home_path(sensor_name: sensor.name, timeframe:)
    end
  end

  private

  CHART_SENSORS = %i[
    autarky
    battery_power
    battery_soc
    car_battery_soc
    case_temp
    co2_reduction
    grid_costs
    grid_power
    grid_revenue
    heatpump_power
    house_power
    power_balance
    inverter_power
    savings
    self_consumption_quote
    total_costs
    wallbox_power
  ].freeze
  private_constant :CHART_SENSORS

  helper_method def chart_sensors
    Sensor::Config.chart_sensors.filter_map do |sensor|
      sensor.name if include_sensor_in_chart?(sensor)
    end
  end

  def include_sensor_in_chart?(sensor)
    # Standard chart sensors (battery, grid, house power, etc.)
    return true if CHART_SENSORS.include?(sensor.name)

    # Custom sensors excluded from house power calculation
    if Sensor::Config.house_power_excluded_custom_sensors.include?(sensor)
      return true
    end

    # Custom inverter powers when not using inverter as total
    sensor.is_a?(Sensor::Definitions::CustomInverterPower) &&
      !Setting.inverter_as_total
  end

  helper_method def forecast_data
    unless timeframe.day? && sensor.name == :inverter_power &&
             Sensor::Config.exists?(:inverter_power_forecast)
      return
    end

    @forecast_data ||=
      begin
        data =
          Sensor::Query::Total
            .new(timeframe) do |q|
              q.sum :inverter_power, :sum
              q.sum :inverter_power_forecast, :sum
            end
            .call
        PowerBalance.new(data)
      end
  end
end
