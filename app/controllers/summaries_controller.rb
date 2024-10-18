class SummariesController < ApplicationController
  def show
    SummarizerJob.perform_now(date)

    render SummaryBuilder::Component::DayComponent.new(
             date:,
             just_created: true,
           )
  end

  private

  def date
    @date ||= Date.parse(params[:date])
  end
end
