class Cars::ChartsController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation
  include SponsoredFrame
  include Cars::Selectable
  include Cars::FrameNavigation

  # A period without charts, like a day, goes to its overview (see
  # Car::Section.charts?)
  def index
    if turbo_frame_request? && Car::Section.charts?(timeframe)
      # Request comes from a single TurboFrame, but we want to update multiple other frames, too
      render formats: :turbo_stream
    else
      # Fallback
      redirect_to cars_home_path(sensor_name: (sensor_name if Car::Section.charts?(timeframe)), timeframe:, **selection_params)
    end
  end
end
