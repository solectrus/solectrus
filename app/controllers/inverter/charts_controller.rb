class Inverter::ChartsController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation

  def index
    if turbo_frame_request?
      # Request comes from a single TurboFrame, but we want to update multiple other frames, too
      render formats: :turbo_stream
    else
      # Fallback
      redirect_to inverter_home_path(sensor_name: sensor.name, timeframe:)
    end
  end

  helper_method def chart_sensors
    Sensor::Config.inverter_sensors.map(&:name)
  end
end
