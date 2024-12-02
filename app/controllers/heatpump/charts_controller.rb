class Heatpump::ChartsController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation

  def index
    render formats: :turbo_stream
  end

  helper_method def chart_sensors
    %i[
      heatpump_heating_power
      heatpump_leaving_temp
      heatpump_cop
      heatpump_score
      outdoor_temp
    ]
  end
end
