class SummariesController < ApplicationController
  include SummaryChecker

  before_action :admin_required!, only: %i[delete_all]

  def show
    @from = Date.parse(params[:date])
    @to = requested_to

    Sensor::Summarizer.new(pending_days).call
  end

  def delete_all
    Summary.reset!

    flash.now[:notice] = t('settings.general.summaries.reset.flash')

    render turbo_stream: [
             turbo_stream.update(
               'summaries',
               partial: 'settings/generals/summaries',
               locals: {
                 summary_completion_rate: 0,
               },
             ),
             turbo_stream_update_flash,
           ]
  end

  private

  # The requesting frame is identified by the first and the last day of its
  # chunk, and those two are not CHUNK_SIZE days apart: a chunk holds up to
  # CHUNK_SIZE days that need a summary, and days that are already fresh sit
  # between them. So the response has to keep the range it was asked for. If it
  # shrinks it, the rendered frame id no longer matches the requesting one and
  # Turbo leaves the page for the bare response.
  def requested_to
    return @from unless params[:to]

    [Date.parse(params[:to]), @from].max
  end

  # One request answers for one chunk, so a hand-crafted range cannot make it
  # summarize years at a time.
  def pending_days
    Summary.missing_or_stale_days(from: @from, to: @to).first(
      Sensor::Summarizer::CHUNK_SIZE,
    )
  end
end
