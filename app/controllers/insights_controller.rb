class InsightsController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation

  def index
    if turbo_frame_request?
      render :index
    else
      # Fallback
      redirect_to root_path(sensor_name: sensor.name, timeframe:)
    end
  end
end
