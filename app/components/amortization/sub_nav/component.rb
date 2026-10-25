# The sub-navigation bar of the amortization page: the chart/table tab switch on
# the left and, at the right edge, the calculation parameters - inline sliders on
# desktop, a slider dropdown on mobile - plus an admin shortcut to the cash-flow
# settings. Rendered into the top bar (content_for :sub_nav) and only shown when
# a real calculation exists to navigate between.
#
# Takes the two calculation parameters rather than the result, so the bar renders
# with the page shell while the calculation is still on its way into the detail
# frame.
class Amortization::SubNav::Component < ViewComponent::Base
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

  # A phone has a title bar when the page is listed in the page More. Its
  # buttons then stand in the title bar, and the row keeps the tabs alone.
  def title_bar? = helpers.more_child_item.present?

  def phone_class = ('max-lg:hidden' if title_bar?)

  # Below lg, unless the title bar has them. A wide screen in landscape has
  # the sliders in the bar.
  def options_class
    title_bar? ? 'shrink-0 hidden lg:block lg:landscape:hidden' : 'shrink-0 lg:landscape:hidden'
  end
end
