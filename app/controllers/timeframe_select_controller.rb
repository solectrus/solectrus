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

  private

  # The page of the sensor in the section the user came from
  helper_method def timeframe_select_base_url
    if referer_namespace == 'balance'
      "/#{sensor_name}"
    else
      "/#{referer_namespace}/#{sensor_name}"
    end
  end
end
