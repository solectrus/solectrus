class AmortizationController < ApplicationController
  include SummaryChecker

  before_action :require_visible_calculation, only: :update

  # Chart view (overview): the balance curve with the KPI rail.
  def show
    build_result
  end

  # Details view: the same calculation shown year by year as a table. Shares all
  # of show's preparation (cash-flow check, summary building, cookie), only the
  # rendered template differs.
  def details
    build_result
  end

  # Recomputes with the two calculation parameters the sliders sent and
  # re-renders the detail Turbo frame. The effective values are remembered in a
  # single per-browser cookie (not a global Setting), so the next plain page
  # load renders the same result server-side without a client round-trip. The
  # slider form carries the active view so the correct template is re-rendered.
  def update
    remember_params

    @result = AmortizationCalculator.result(period_years:, interest_rate:)
    render current_view == :details ? :details : :show
  end

  private

  # Which of the two views is active: the current action, or - on a
  # slider-triggered frame update (action 'update') - whichever tab the form
  # declared via :view. The single source for both the render branch and the
  # sub-navigation's active tab.
  helper_method def current_view
    action_name == 'details' || params[:view] == 'details' ? :details : :chart
  end

  # Shared preparation for both the chart and the table view.
  def build_result
    # No cash flows yet means nothing to calculate - the view shows a hint to
    # create them instead.
    return unless CashFlow.exists?

    # The measured savings come from the daily summaries. Build any missing ones
    # first (same mechanism as Top10) so the calculation - and its day-long
    # cache entry - runs on complete data instead of a partial set.
    load_missing_or_stale_summary_days(timeframe)
    return if @missing_or_stale_summary_days.present?

    # Refresh the expiry on every visit (sliding expiration) so a customized
    # setting survives for regular visitors well beyond the browsers' ~400-day
    # cap - but only if the visitor already has one, to avoid handing a cookie
    # to everyone who just looks at the defaults.
    remember_params if cookie_params.present?

    @result = AmortizationCalculator.result(period_years:, interest_rate:)
  end

  # Sub-navigation between the chart (overview) and the table (details). The
  # active tab follows the current action, so a slider-triggered frame update
  # (action_name 'update') keeps whichever tab the form declared via its view.
  helper_method def nav_items
    on_details = current_view == :details

    [
      {
        name: t('amortization.nav.chart'),
        href: amortization_path,
        current: !on_details,
      },
      {
        name: t('amortization.nav.details'),
        href: details_amortization_path,
        current: on_details,
      },
    ]
  end

  helper_method def title
    t('layout.amortization')
  end

  # The whole operating range (installation date up to today) - the summaries
  # need to be complete over the entire period the calculation spans.
  helper_method def timeframe
    @timeframe ||= Timeframe.all
  end

  # The sliders are shown to everyone who may see the calculation, so the same
  # visibility (sponsor feature, and either admin or made public) guards the
  # update action.
  def require_visible_calculation
    return if ApplicationPolicy.amortization? &&
      (admin? || Setting.amortization_public)

    raise ForbiddenError
  end

  # The slider parameters, defaulted and clamped into the allowed range. Taken
  # from the request when a slider was just moved, otherwise from the
  # per-browser cookie set on the last change, otherwise the default. Clamping
  # also guards against a tampered cookie.
  def period_years
    @period_years ||= AmortizationCalculator.clamp_period(stored(:period_years))
  end

  def interest_rate
    @interest_rate ||=
      AmortizationCalculator.clamp_interest(stored(:interest_rate))
  end

  # Persists the effective parameters in one JSON cookie. cookies.permanent
  # asks for a 20-year expiry (browsers cap it at ~400 days), refreshed on
  # every visit via the sliding expiration in #show.
  def remember_params
    cookies.permanent[:amortization_params] = {
      period_years:,
      interest_rate:,
    }.to_json
  end

  def stored(name)
    params.dig(:amortization, name).presence || cookie_params[name.to_s]
  end

  # Both parameters live in one JSON cookie; an absent or malformed cookie
  # falls back to an empty hash (and thus to the defaults).
  def cookie_params
    @cookie_params ||=
      begin
        parsed = JSON.parse(cookies[:amortization_params].to_s)
        parsed.is_a?(Hash) ? parsed : {}
      rescue JSON::ParserError
        {}
      end
  end
end
