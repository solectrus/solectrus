class Inverter::ChartsController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation

  def index
    if turbo_frame_request?
      # Request comes from a single TurboFrame, but we want to update multiple other frames, too
      render formats: :turbo_stream
    else
      # Fallback
      redirect_to inverter_home_path(sensor:, timeframe:)
    end
  end

  helper_method def chart_sensors
    ([:inverter_power] + SensorConfig.x.inverter_sensor_names).uniq
  end
end
