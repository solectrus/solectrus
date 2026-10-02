# The timeframe select of the list of the charging sessions. The new address
# keeps the kind and the car of the list.
class ChargingSessions::TimeframeSelectController < ApplicationController
  before_action :admin_required!

  def index
    if turbo_frame_request?
      render 'timeframe_select/index'
    else
      redirect_to charging_sessions_path(kind:, timeframe:, car: params[:car])
    end
  end

  private

  helper_method def timeframe
    @timeframe ||= Timeframe.new(params[:timeframe])
  end

  helper_method def timeframe_select_base_url
    charging_sessions_path(kind:)
  end

  def kind
    params[:kind]
  end
end
