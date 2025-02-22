class SummariesController < ApplicationController
  include SummaryChecker

  before_action :admin_required!, only: %i[delete_all]

  def show
    @date = Date.parse(params[:date])
    SummarizerJob.perform_now(@date)
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
end
