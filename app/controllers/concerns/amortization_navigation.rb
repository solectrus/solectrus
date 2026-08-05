# Tab navigation of the amortization page: which views there are, which of them
# the request is asking for, and where each one lives. Kept together because
# adding a tab is then a single entry here plus a route.
module AmortizationNavigation
  extend ActiveSupport::Concern

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

  included do
    private

    # Which of the views is active: whichever tab the request declared via
    # :view - that is how a request that only (re)renders the detail frame says
    # which tab it belongs to - otherwise the current action. The single source
    # for both the render branch and the active tab below; anything unknown (the
    # 'show' and 'update' actions included) falls back to the chart.
    helper_method def current_view
      requested = (params[:view].presence || action_name).to_s.to_sym

      VIEWS.key?(requested) ? requested : :chart
    end

    # The page a view lives on - the frame fragments have no URL of their own.
    def view_path(view = current_view) = public_send(VIEWS[view])

    helper_method def nav_items
      VIEWS.each_key.map do |view|
        {
          name: t("amortization.nav.#{view}"),
          href: view_path(view),
          current: current_view == view,
        }
      end
    end
  end
end
