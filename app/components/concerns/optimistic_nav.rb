# The actions of a navigation whose marking moves to the tapped item at once
# and slides there, see optimistic_nav_controller.ts. Nav::Sub::Component and
# Ui::SegmentedControl::Component share them.
module OptimisticNav
  ACTIONS = %w[
    turbo:click->optimistic-nav#markCurrent
    turbo:before-render@document->optimistic-nav#handoff
    turbo:fetch-request-error@document->optimistic-nav#restore
    turbo:load@document->optimistic-nav#settle
  ].join(' ').freeze
  public_constant :ACTIONS
end
