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
        Queries::Calculation.new(:balcony_inverter_power, :sum, :sum),
      ],
    )
  end

  helper_method def chart_sensors
    %i[
      inverter_power
      balcony_inverter_power
      total_inverter_power
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
    ] + SensorConfig.x.excluded_custom_sensor_names
  end
end
