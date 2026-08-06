class SummariesController < ApplicationController
  include SummaryChecker

  before_action :admin_required!, only: %i[delete_all]

  def show
    @from = Date.parse(params[:date])
    @to = requested_to

    Sensor::Summarizer.call(@from..@to)
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

  # One request answers for one chunk, so a hand-crafted range cannot make it
  # summarize years at a time.
  def requested_to
    return @from unless params[:to]

    to = Date.parse(params[:to])
    to.clamp(@from, @from + Sensor::Summarizer::CHUNK_SIZE - 1)
  end
end
