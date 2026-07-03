class AmortizationController < ApplicationController
  include SummaryChecker

  before_action :require_editable_parameters, only: :update

  def index
    # No cash flows yet means nothing to calculate - the view shows a hint to
    # create them instead.
    return unless CashFlow.exists?

    # The measured savings come from the daily summaries. Build any missing ones
    # first (same mechanism as Top10) so the calculation - and its day-long
    # cache entry - runs on complete data instead of a partial set.
    load_missing_or_stale_summary_days(timeframe)
    return if @missing_or_stale_summary_days.present?

    @result = AmortizationCalculator.result
  end

  # Persists the two calculation parameters adjusted via the sliders and
  # re-renders the detail Turbo frame with the recalculated result.
  def update
    if (value = period_param)
      Setting.amortization_period_years =
        value.to_i.clamp(AmortizationControls::Component::PERIOD_RANGE)
    end

    if (value = interest_param)
      Setting.amortization_interest_rate =
        value.to_f.clamp(AmortizationControls::Component::INTEREST_RANGE)
    end

    @result = AmortizationCalculator.result
    render :index
  end

  private

  helper_method def title
    t('layout.amortization')
  end

  # The whole operating range (installation date up to today) - the summaries
  # need to be complete over the entire period the calculation spans.
  helper_method def timeframe
    @timeframe ||= Timeframe.all
  end

  # The sliders exist only for admins with the sponsor feature, so the same
  # combination guards the update action.
  def require_editable_parameters
    return if admin? && ApplicationPolicy.amortization?

    raise ForbiddenError
  end

  def period_param
    params.dig(:amortization, :period_years).presence
  end

  def interest_param
    params.dig(:amortization, :interest_rate).presence
  end
end
