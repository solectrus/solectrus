class Heatpump::ChartsController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation

  def index
    render formats: :turbo_stream
  end

  helper_method def chart_sensors
    %i[
      heatpump_power
      heatpump_heating_power
      heatpump_cop
      outdoor_temp
      heatpump_tank_temp
    ]
  end
end
