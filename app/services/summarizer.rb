class Summarizer
  def initialize(timeframe:)
    @timeframe = timeframe
  end

  attr_reader :timeframe

  def perform_now!
    dates_to_process.each { |date| SummarizerJob.perform_now(date) }.count
  end

  private

  def dates_to_process
    Summary.missing_or_stale_days(
      from: timeframe.effective_beginning_date,
      to: timeframe.effective_ending_date,
    )
  end
end
