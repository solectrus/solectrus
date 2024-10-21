module SummaryChecker
  extend ActiveSupport::Concern

  def load_missing_or_stale_summary_days(timeframe)
    @missing_or_stale_summary_days = missing_or_stale_summary_days(timeframe)
  end

  private

  def missing_or_stale_summary_days(timeframe)
    # For "now" we don't need summaries at all
    return [] if timeframe.now?

    # For single days we need the summary to be present, but we don't need to wait for it.
    # It can created on the fly in the StatsController, if missing.
    return [] if timeframe.day?

    # Timeframe is longer (week / month / year / all) and summaries are missing.
    # This is the only case where we need to wait for the summaries to be created.
    Summary.missing_or_stale_days(
      from: timeframe.effective_beginning_date,
      to: timeframe.effective_ending_date,
    )
  end
end
