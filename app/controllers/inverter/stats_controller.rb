class Inverter::StatsController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation

  before_action :refresh_summaries_if_needed

  def index
    if turbo_frame_request?
      # Request comes from a single TurboFrame, but we want to update multiple other frames, too
      render formats: :turbo_stream
    else
      # Fallback
      redirect_to inverter_home_path(sensor:, timeframe:)
    end
  end

  private

  def refresh_summaries_if_needed
    return if timeframe.now?

    # In most cases, stale summaries are not possible when we get here, because this was
    # already checked in HomeController#index. But there is one exception: when the
    # user comes back to the page without navigation, then the JS reloads the frames
    # directly, without going through HomeController#index.
    Summarizer.new(timeframe:).perform_now!
  end

  def calculator_now
    Calculator::Now.new(
      %i[system_status] + SensorConfig.x.inverter_sensor_names,
    )
  end

  def calculator_range
    Calculator::Range.new(
      timeframe,
      calculations:
        SensorConfig.x.inverter_sensor_names.flat_map do |sensor_name|
          [Queries::Calculation.new(sensor_name, :sum, :sum)]
        end,
    )
  end
end
