class Summarizer
  def initialize(from: nil, to: nil)
    @from = [from, Rails.configuration.x.installation_date].compact.max
    @to = [to, Date.current].compact.min
    return if @from <= @to

    raise ArgumentError, "Summarizer: #{@from} - #{@to} is not a valid range!"
  end

  attr_reader :from, :to

  def perform_now!
    dates_to_process.each { |date| SummarizerJob.perform_now(date) }.count
  end

  private

  def dates_to_process
    Summary.missing_or_stale_days(from:, to:)
  end
end
