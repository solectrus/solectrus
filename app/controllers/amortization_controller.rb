class AmortizationController < ApplicationController
  include AmortizationNavigation

  before_action :ensure_enabled
  before_action :require_visible_calculation, only: %i[content update]

  # Chart view (overview): the balance curve with the KPI rail. Only the page
  # shell - the calculation is fetched into the detail frame separately (see
  # #content), so navigation, sub-navigation and sliders are on screen
  # immediately.
  def show
    @page = AmortizationPage.shell(visibility:, preferences:)

    # Refresh the expiry on every visit (sliding expiration) so a customized
    # setting survives for regular visitors well beyond the browsers' ~400-day
    # cap - but only if the visitor already has one, to avoid handing a cookie
    # to everyone who just looks at the defaults.
    remember_params if @page.calculation? && preferences.customized?

    render :show
  end

  # The other two tabs - the return history and the year-by-year table - show
  # the same calculation in the same shell; which of them is active is decided
  # by #current_view, so all three actions render the same template.
  def returns = show

  def details = show

  # The calculation itself, rendered into the detail frame the page shell left
  # empty. On a cold cache the computation takes noticeably longer than the rest
  # of the page, which is why it gets a request of its own.
  def content
    redirect_to view_path and return unless turbo_frame_request?

    @page = detail_page
  end

  # Recomputes with the two calculation parameters the sliders sent and
  # re-renders the detail Turbo frame. The effective values are remembered in a
  # single per-browser cookie (not a global Setting), so the next plain page
  # load renders the same result server-side without a client round-trip. The
  # slider form carries the active view so the correct content is re-rendered.
  def update
    remember_params

    @page = detail_page
    render :content
  end

  private

  def visibility = @visibility ||= AmortizationVisibility.new(admin: admin?)

  def detail_page
    AmortizationPage.detail(visibility:, preferences:)
  end

  def ensure_enabled
    return if visibility.enabled?

    raise ActionController::RoutingError, request.path
  end

  # The sliders are shown to everyone who may see the calculation, so the same
  # visibility guards the frame and the update action.
  def require_visible_calculation
    raise ForbiddenError unless visibility.visible?
  end

  helper_method def title
    t('layout.amortization')
  end

  # The effective slider parameters for this request.
  def preferences
    @preferences ||=
      AmortizationPreferences.new(
        submitted: submitted_params,
        cookie: cookies[AmortizationPreferences::COOKIE_NAME],
      )
  end

  # What the slider form sent, if anything. Anything else arriving under
  # :amortization is not a submission and leaves the cookie (or the default) in
  # charge.
  def submitted_params
    submitted = params[:amortization]
    return {} unless submitted.is_a?(ActionController::Parameters)

    submitted.permit(:period_years, :interest_rate).to_h
  end

  # Persists the effective parameters in one JSON cookie. cookies.permanent
  # asks for a 20-year expiry (browsers cap it at ~400 days).
  def remember_params
    cookies.permanent[AmortizationPreferences::COOKIE_NAME] =
      preferences.to_cookie
  end
end
