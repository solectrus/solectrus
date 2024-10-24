class SummariesController < ApplicationController
  include SummaryChecker

  def show
    @date = Date.parse(params[:date])
    SummarizerJob.perform_now(@date)
  end
end
