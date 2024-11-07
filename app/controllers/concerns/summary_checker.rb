module SummaryChecker
  extend ActiveSupport::Concern

  def load_missing_or_stale_summary_days(timeframe)
    @missing_or_stale_summary_days = missing_or_stale_summary_days(timeframe)
  end

  private

  def missing_or_stale_summary_days(timeframe)
    # For "now" we don't need summaries at all
    return [] if timeframe.now?

    Summary.missing_or_stale_days(
      from: timeframe.effective_beginning_date,
      to: timeframe.effective_ending_date,
    )
  end
end
