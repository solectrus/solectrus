class AmortizationController < ApplicationController
  include SummaryChecker

  before_action :ensure_enabled
  before_action :require_visible_calculation, only: %i[content update]

  # Chart view (overview): the balance curve with the KPI rail.
  def show
    prepare_page
  end

  # The other two tabs - the return history and the year-by-year table - show
  # the same calculation and need the same preparation (cash-flow check, summary
  # building, cookie); only the template Rails renders for them differs.
  def returns = show

  def details = show

  # The calculation itself, rendered into the detail frame the page shell left
  # empty. On a cold cache the computation takes noticeably longer than the rest
  # of the page, so it is fetched separately: navigation, sub-navigation and
  # sliders are on screen immediately, the figures follow into the frame.
  def content
    redirect_to view_path and return unless turbo_frame_request?

    build_result
  end

  # Recomputes with the two calculation parameters the sliders sent and
  # re-renders the detail Turbo frame. The effective values are remembered in a
  # single per-browser cookie (not a global Setting), so the next plain page
  # load renders the same result server-side without a client round-trip. The
  # slider form carries the active view so the correct content is re-rendered.
  def update
    remember_params

    build_result
    render :content
  end

  private

  # The tabs, in navigation order, each with the page it lives on: the charts
  # come first - the same calculation in euros and in percent - with the
  # year-by-year table last as the drill-down. :chart is the default (and the
  # show action), the others are named after their own action.
  VIEWS = {
    chart: :amortization_path,
    returns: :returns_amortization_path,
    details: :details_amortization_path,
  }.freeze
  private_constant :VIEWS

  # Which of the views is active: whichever tab the request declared via :view -
  # that is how a request that only (re)renders the detail frame says which tab
  # it belongs to - otherwise the current action. The single source for both the
  # render branch and the sub-navigation's active tab; anything unknown (the
  # 'show' and 'update' actions included) falls back to the chart.
  helper_method def current_view
    requested = (params[:view].presence || action_name).to_s.to_sym

    VIEWS.key?(requested) ? requested : :chart
  end

  # The page a view lives on - the frame fragments have no URL of their own.
  def view_path(view = current_view) = public_send(VIEWS[view])

  # Everything the page shell needs - deliberately without the calculation
  # itself, which the detail frame fetches separately (see #content).
  def prepare_page
    # Every other state is a hint with nothing behind it to prepare.
    return unless page_state == :calculation

    # The measured savings come from the daily summaries. Build any missing ones
    # first (same mechanism as Top10) so the calculation - and its day-long
    # cache entry - runs on complete data instead of a partial set.
    load_missing_or_stale_summary_days(timeframe)

    # Deferring the calculation only pays off while it is expensive. It is
    # cached for a day, so on every visit but the first the figures are a cache
    # read away - cheaper than the round-trip the frame would make for them, and
    # without the spinner flash. On a miss @result stays nil and the frame
    # fetches it (see #content).
    @result =
      AmortizationCalculator.cached_result(period_years:, interest_rate:)

    # Refresh the expiry on every visit (sliding expiration) so a customized
    # setting survives for regular visitors well beyond the browsers' ~400-day
    # cap - but only if the visitor already has one, to avoid handing a cookie
    # to everyone who just looks at the defaults.
    remember_params if cookie_params.present?
  end

  # The calculation runs on complete daily summaries only - the frame shows the
  # builder for the missing ones instead. Checked here rather than in the shell
  # alone: the frame arrives a moment later, and its result is cached for a day
  # under a key that knows nothing about summary completeness, so a partial set
  # would be served until midnight.
  def build_result
    load_missing_or_stale_summary_days(timeframe)
    return if @missing_or_stale_summary_days.present?

    @result = AmortizationCalculator.result(period_years:, interest_rate:)
  end

  # What the page shell shows - the states are mutually exclusive and the
  # template renders exactly one of them, so the decision is made here instead
  # of being spelled out again as a chain of booleans in the view. The order is
  # deliberate: a viewer who is only missing the login is told so rather than
  # being sent to the sponsor teaser. Asked several times per render (layout,
  # sub-navigation, body), hence memoized.
  helper_method def page_state
    @page_state ||=
      if !viewer_allowed?
        :restricted
      elsif !ApplicationPolicy.amortization?
        :unavailable
      elsif !CashFlow.exists?
        :no_cash_flows
      else
        :calculation
      end
  end

  # Whether the page will show a real calculation - as far as that can be told
  # without computing it. Drives the layout and the sub-navigation, so both come
  # with the shell instead of waiting for the frame. Only the rare "no prognosis
  # possible yet" case cannot be told apart here; it then renders inside the
  # calculation's layout rather than the hint's.
  helper_method def calculation_expected?
    page_state == :calculation && @missing_or_stale_summary_days.blank?
  end

  # Sub-navigation between the two charts and the table. The active tab follows
  # the current action, so a frame render (action 'content' or 'update') keeps
  # whichever tab the request declared via its view.
  helper_method def nav_items
    VIEWS.each_key.map do |view|
      {
        name: t("amortization.nav.#{view}"),
        href: view_path(view),
        current: current_view == view,
      }
    end
  end

  helper_method def title
    t('layout.amortization')
  end

  # The whole operating range (installation date up to today) - the summaries
  # need to be complete over the entire period the calculation spans.
  helper_method def timeframe
    @timeframe ||= Timeframe.all
  end

  # Disabling the feature entirely ('none' visibility) removes the navigation
  # entry; a direct request must 404 like any unknown URL - for everyone,
  # admins included.
  def ensure_enabled
    return if Setting.enable_amortization

    raise ActionController::RoutingError, request.path
  end

  # Whether this viewer is past the login barrier: the calculation is either
  # public or the viewer is an admin. Says nothing about the sponsor feature.
  def viewer_allowed?
    admin? || Setting.amortization_public
  end

  # Whether this viewer may see the calculation: the sponsor feature must be
  # active and the calculation either admin-viewed or made public. Everyone else
  # gets a hint, so nothing is computed and no sub-navigation is shown.
  def calculation_visible?
    ApplicationPolicy.amortization? && viewer_allowed?
  end

  # The sliders are shown to everyone who may see the calculation, so the same
  # visibility guards the update action.
  def require_visible_calculation
    raise ForbiddenError unless calculation_visible?
  end

  # The slider parameters, defaulted and clamped into the allowed range. Taken
  # from the request when a slider was just moved, otherwise from the
  # per-browser cookie set on the last change, otherwise the default. Clamping
  # also guards against a tampered cookie. Known without computing anything, so
  # the sliders render with the shell.
  helper_method def period_years
    @period_years ||= AmortizationCalculator.clamp_period(stored(:period_years))
  end

  helper_method def interest_rate
    @interest_rate ||=
      AmortizationCalculator.clamp_interest(stored(:interest_rate))
  end

  # Persists the effective parameters in one JSON cookie. cookies.permanent
  # asks for a 20-year expiry (browsers cap it at ~400 days), refreshed on
  # every visit via the sliding expiration in #prepare_page.
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
