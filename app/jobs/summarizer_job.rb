class SummarizerJob < ApplicationJob
  queue_as :default

  def perform(date)
    Sensor::Summarizer.new(date).call
  end

  def self.perform_for_timeframe(timeframe, method = :perform_now)
    raise ArgumentError unless timeframe.is_a?(Timeframe)
    raise ArgumentError if timeframe.now?
    raise ArgumentError unless method.in?(%i[perform_now perform_later])

    dates_to_process =
      Summary.missing_or_stale_days(
        from: timeframe.effective_beginning_date,
        to: timeframe.effective_ending_date,
      )

    dates_to_process.each { |date| public_send(method, date) }
    dates_to_process.count
  end
end
