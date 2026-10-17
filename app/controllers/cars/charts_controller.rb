class Cars::ChartsController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation
  include SponsoredFrame
  include CarSelectable

  def index
    if turbo_frame_request?
      # Request comes from a single TurboFrame, but we want to update multiple other frames, too
      render formats: :turbo_stream
    else
      # Fallback
      redirect_to cars_home_path(sensor_name:, timeframe:, **selection_params)
    end
  end
end
