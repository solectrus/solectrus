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

  # We need to create summaries for all missing and outdated dates
  def dates_to_process
    missing_dates + outdated_dates
  end

  # Find dates in the range without a summary
  def missing_dates
    (from..to).to_a - existing_dates
  end

  # Find dates in the range with a summary
  def existing_dates
    scope.pluck(:date)
  end

  # Find dates in the range with an OUTDATED summary
  def outdated_dates
    scope.outdated.pluck(:date)
  end

  def scope
    Summary.where(date: from..to)
  end
end
