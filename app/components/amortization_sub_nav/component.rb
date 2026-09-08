# The sub-navigation bar of the amortization page: the chart/table tab switch on
# the left and, at the right edge, the calculation parameters - inline sliders on
# desktop, a slider dropdown on mobile - plus an admin shortcut to the cash-flow
# settings. Rendered into the top bar (content_for :sub_nav) and only shown when
# a real calculation exists to navigate between.
#
# Takes the two calculation parameters rather than the result, so the bar renders
# with the page shell while the calculation is still on its way into the detail
# frame.
class AmortizationSubNav::Component < ViewComponent::Base
  def initialize(
    period_years:,
    interest_rate:,
    projection_uncertain:,
    view: :chart
  )
    super()
    @period_years = period_years
    @interest_rate = interest_rate
    @view = view
    @projection_uncertain = projection_uncertain
  end

  attr_reader :period_years, :interest_rate, :view, :projection_uncertain

  delegate :nav_items, :admin?, to: :helpers
end
