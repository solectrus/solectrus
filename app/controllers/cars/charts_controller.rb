class Cars::ChartsController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation
  include SponsoredFrame
  include CarSelectable

  # A guest gets the chart of a personal sensor without its data (see
  # ChartLoader::Component)
  skip_before_action :forbid_personal_sensor

  def index
    if turbo_frame_request?
      # Request comes from a single TurboFrame, but we want to update multiple other frames, too
      render formats: :turbo_stream
    else
      # Fallback
      redirect_to cars_home_path(sensor_name:, timeframe:, **selection_params)
    end
  end

  private

  # The map of the places reaches the edges of the card
  helper_method def map? = Sensor::Registry[sensor_name].chart(timeframe, **chart_options)&.type == 'map'
end
