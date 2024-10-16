class SummariesController < ApplicationController
  def show
    SummarizerJob.perform_now(date)

    render SummaryBuilder::Component::DayComponent.new(date:)
  end

  private

  def date
    @date ||= Date.parse(params[:date])
  end
end
