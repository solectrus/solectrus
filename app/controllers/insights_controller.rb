class InsightsController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation

  def index
    if turbo_frame_request?
      render :index
    else
      # Fallback
      redirect_to balance_home_path(sensor_name: sensor.name, timeframe:)
    end
  end
end
