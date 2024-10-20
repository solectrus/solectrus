module SummaryChecker
  extend ActiveSupport::Concern

  def load_missing_summary_days(timeframe)
    @missing_summary_days =
      (summaries_missing?(timeframe) ? Summary.missing_days(timeframe) : [])
  end

  private

  def summaries_missing?(timeframe)
    # For "now" we don't need summaries at all
    return false if timeframe.now?

    # For single days we need the summary to be present, but we don't need to wait for it.
    # It can created on the fly in the StatsController, if missing.
    return false if timeframe.day?

    # If the summary is already present, we can continue.
    return false if Summary.completed?(timeframe)

    # Timeframe is longer (week / month / year / all) and summaries are missing.
    # This is the only case where we need to wait for the summaries to be created.
    true
  end
end
