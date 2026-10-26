class Cars::StatsController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation
  include SponsoredFrame
  include Cars::Selectable
  include Cars::FrameNavigation

  before_action :refresh_summaries_if_needed

  def index
    if turbo_frame_request?
      # The curves of the timeline load while the figures render
      day_timeline&.start

      # Request comes from a single TurboFrame, but we want to update multiple other frames, too
      render formats: :turbo_stream
    else
      # Fallback
      redirect_to cars_home_path(timeframe:, **selection_params)
    end
  end

  private

  def refresh_summaries_if_needed
    return if timeframe.now?

    # In most cases, stale summaries are not possible when we get here, because this was
    # already checked in HomeController#index. But there is one exception: when the
    # user comes back to the page without navigation, then the JS reloads the frames
    # directly, without going through HomeController#index.
    Sensor::Summarizer.new(Car::Report.pending_days(timeframe)).call
  end

  # The live view shows Car::Live for each car in use today, without a
  # select, and a period Car::Report. The page has no hours view (see
  # Sensor::HomePage.hours?).
  def data_now = Car::Live.new(car_selection.offered)

  def data_range = Car::Report.new(timeframe, cars, guest: car_selection.with_guest?)

  # The timeline of a day, below its figures (see Car::DayTimeline)
  helper_method def day_timeline
    return unless timeframe.day?

    @day_timeline ||= Car::DayTimeline.new(timeframe, cars, guest: car_selection.with_guest?, admin: admin?)
  end
end
