class Balance::ChartsController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation

  def index
    render formats: :turbo_stream
  end

  private

  def calculations
    {
      inverter_power: :sum_inverter_power_sum,
      inverter_power_forecast: :sum_inverter_power_forecast_sum,
    }
  end

  helper_method def chart_sensors
    %i[
      inverter_power
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
    ]
  end
end
