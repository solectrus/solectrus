class SummariesController < ApplicationController
  include SummaryChecker

  before_action :admin_required!, only: %i[delete_all]

  def show
    @date = Date.parse(params[:date])
    SummarizerJob.perform_now(@date)
  end

  def delete_all
    Summary.delete_all

    redirect_to settings_path, notice: t('crud.success')
  end
end
