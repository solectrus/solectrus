class Balance::ChartsController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation

  def index
    if turbo_frame_request?
      # Request comes from a single TurboFrame, but we want to update multiple other frames, too
      render formats: :turbo_stream
    else
      # Fallback
      redirect_to root_path(sensor_name: sensor.name, timeframe:)
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
    inverter_power
    savings
    self_consumption_quote
    total_costs
    wallbox_power
  ].freeze
  private_constant :CHART_SENSORS

  helper_method def chart_sensors
    Sensor::Config.chart_sensors.filter_map do |sensor|
      sensor.name if CHART_SENSORS.include?(sensor.name)
    end
  end

  helper_method def forecast_data
    unless timeframe.day? && sensor.name == :inverter_power &&
             Sensor::Config.exists?(:inverter_power_forecast)
      return
    end

    @forecast_data ||=
      begin
        data =
          Sensor::Query::Sql
            .new do |q|
              q.sum :inverter_power, :sum
              q.sum :inverter_power_forecast, :sum
              q.timeframe timeframe
            end
            .call
        PowerBalance.new(data)
      end
  end
end
