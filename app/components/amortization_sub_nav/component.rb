# The sub-navigation bar of the amortization page: the chart/table tab switch on
# the left and, at the right edge, the calculation parameters - inline sliders on
# desktop, a slider dropdown on mobile - plus an admin shortcut to the cash-flow
# settings. Rendered into the top bar (content_for :sub_nav) and only shown when
# a real calculation exists to navigate between.
class AmortizationSubNav::Component < ViewComponent::Base
  def initialize(result:, view: :chart)
    super()
    @result = result
    @view = view
  end

  attr_reader :result, :view

  delegate :nav_items, :admin?, to: :helpers
end
