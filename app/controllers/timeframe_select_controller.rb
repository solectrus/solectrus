class TimeframeSelectController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation
  include RefererNamespace

  def index
    if turbo_frame_request?
      render :index
    else
      # Fallback: the home page that shows this sensor, not always the balance
      redirect_to helpers.sensor_home_path(sensor.name, timeframe:)
    end
  end

  helper_method :referer_namespace
end
