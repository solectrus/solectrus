class TimeframeSelectController < ApplicationController
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

  helper_method :controller_namespace

  private

  def controller_namespace
    if request.referer.include?('/house/')
      'house'
    elsif request.referer.include?('/inverter/')
      'inverter'
    elsif request.referer.include?('/heatpump/')
      'heatpump'
    else
      'balance'
    end
  end
end
