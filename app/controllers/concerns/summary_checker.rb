module SummaryChecker
  extend ActiveSupport::Concern

  def load_missing_or_stale_summary_days(timeframe)
    @missing_or_stale_summary_days = Sensor::Summarizer.build_few(Summary.missing_or_stale_days_for(timeframe))
  end
end
