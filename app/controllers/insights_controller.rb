class InsightsController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation

  def index
    if turbo_frame_request?
      render :index
    else
      # Fallback: the home page that shows this sensor, not always the balance
      redirect_to helpers.sensor_home_path(sensor.name, timeframe:)
    end
  end

  helper_method :controller_namespace

  private

  # The page that holds the frame decides which navigation the insights belong
  # to. A browser does not always send a referer -- its referrer policy can
  # remove it -- and the balance is then the default.
  def controller_namespace
    referer = request.referer.to_s

    if referer.include?('/house/')
      'house'
    elsif referer.include?('/inverter/')
      'inverter'
    elsif referer.include?('/heatpump/')
      'heatpump'
    else
      'balance'
    end
  end
end
