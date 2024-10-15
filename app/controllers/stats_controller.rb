class StatsController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation

  def index
    ensure_summaries_present!

    render formats: :turbo_stream
  end

  private

  def ensure_summaries_present!
    return if timeframe.now? || Summary.completed?(timeframe)

    SummarizerJob.perform_now(timeframe.date) if timeframe.day?
  end
end
