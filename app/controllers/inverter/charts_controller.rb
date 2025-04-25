class Inverter::ChartsController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation

  def index
    render formats: :turbo_stream
  end

  helper_method def chart_sensors
    ([:inverter_power] + SensorConfig.x.inverter_sensor_names).uniq
  end
end
