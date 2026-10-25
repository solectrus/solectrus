# A navigation whose marking moves to the tapped item at once, see
# optimistic_nav_controller.ts. With `slide: true`, the marking slides there.
# Ui::Chips::Component, Ui::SegmentedControl::Component and
# Nav::Sub::Component use it.
#
#   = tag.nav data: Ui::OptimisticNav.data(slide: true) do
module Ui::OptimisticNav
  ACTIONS = %w[
    turbo:click->optimistic-nav#markCurrent
    turbo:before-render@document->optimistic-nav#handoff
    turbo:fetch-request-error@document->optimistic-nav#restore
    turbo:load@document->optimistic-nav#settle
  ].join(' ').freeze
  public_constant :ACTIONS

  # The data of the element that holds the items. The keys carry dashes, so
  # Slim writes them as Rails does.
  def self.data(slide: false)
    { controller: 'optimistic-nav', 'optimistic-nav-slide-value': ('true' if slide), action: ACTIONS }.compact
  end
end
