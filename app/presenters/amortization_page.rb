# What the amortization page shows - decided without rendering anything, so the
# templates only have to branch, not to reason. It answers three questions:
# which of the four mutually exclusive states applies, whether the daily
# summaries the calculation needs are complete, and what the calculation says.
#
# Comes in two flavors, one per request the page makes:
#
#   .shell  - the page frame, rendered first. Takes the calculation only if it
#             happens to be cached already, so the first paint never waits for
#             it (see AmortizationController#content).
#   .detail - the contents of the detail frame, where the calculation is
#             computed if it has to be.
class AmortizationPage
  def self.shell(visibility:, preferences:)
    new(visibility:, preferences:, compute: false)
  end

  def self.detail(visibility:, preferences:)
    new(visibility:, preferences:, compute: true)
  end

  def initialize(visibility:, preferences:, compute:)
    @visibility = visibility
    @preferences = preferences
    @compute = compute
  end

  delegate :period_years, :interest_rate, to: :preferences

  # The state of the page: whatever keeps this viewer from the calculation
  # (asked of the visibility, which owns that order), otherwise whether there is
  # anything to calculate from at all.
  def state
    @state ||=
      visibility.denial_reason ||
        (CashFlow.exists? ? :calculation : :no_cash_flows)
  end

  def calculation? = state == :calculation

  # Whether the page will show a real calculation - as far as that can be told
  # without computing it. Drives the layout and the sub-navigation, so both come
  # with the shell instead of waiting for the frame. Only the rare "no prognosis
  # possible yet" case cannot be told apart here; it then renders inside the
  # calculation's layout rather than the hint's.
  def calculation_expected? = calculation? && missing_or_stale_days.blank?

  # The whole operating range (installation date up to today) - the summaries
  # need to be complete over the entire period the calculation spans.
  def timeframe = @timeframe ||= Timeframe.all

  # The measured savings come from the daily summaries. The missing ones have to
  # be built first (same mechanism as Top10) so the calculation - and its
  # day-long cache entry - runs on complete data instead of a partial set.
  def missing_or_stale_days
    @missing_or_stale_days ||=
      calculation? ? Summary.missing_or_stale_days_for(timeframe) : []
  end

  # The calculation, or nil while there is none to show yet.
  def result
    return @result if defined?(@result)

    @result = calculation_expected? ? load_result : nil
  end

  # Whether the detail frame's contents are already at hand, so the shell can
  # render them inline instead of having the frame fetch itself. That is either
  # the calculation or - just as final an answer - the summary builder that
  # takes its place.
  def detail_ready? = missing_or_stale_days.present? || !result.nil?

  private

  attr_reader :visibility, :preferences, :compute

  # The shell never computes: the calculation is cached for a day, so on every
  # visit but the first it is a cache read away - cheaper than the round-trip
  # the frame would make for it, and without the spinner flash. On a miss the
  # shell renders an empty frame and the frame fetches itself.
  def load_result
    if compute
      AmortizationCalculator.result(period_years:, interest_rate:)
    else
      AmortizationCalculator.cached_result(period_years:, interest_rate:)
    end
  end
end
