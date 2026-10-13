# A segmented control of iOS on the page: a few pages of the same level side
# by side, the current one raised. Items are hashes with :name, :href and
# :current, as the items of Nav::Sub::Component. The look follows the toggle
# of the cards on the car page (Car::CardToggle::Component), on white and on
# gray.
class Ui::SegmentedControl::Component < ViewComponent::Base
  ITEM_CLASS =
    'relative rounded-md px-4 py-1 text-center text-sm font-medium whitespace-nowrap focus-ring'.freeze

  CURRENT_CLASS = 'bg-white text-slate-800 shadow-sm dark:bg-slate-600 dark:text-white'.freeze

  OTHER_CLASS = 'text-slate-500 dark:text-slate-400'.freeze
  private_constant :ITEM_CLASS, :CURRENT_CLASS, :OTHER_CLASS

  def initialize(items:, label:)
    super()
    @items = items
    @label = label
  end

  # The raised segment moves to the tapped one at once and slides there, as
  # the period tabs
  def call
    tag.nav class: 'relative inline-flex rounded-lg bg-slate-500/12 p-1 dark:bg-slate-800',
            'aria-label': @label,
            data: { controller: 'optimistic-nav', optimistic_nav_slide_value: true, action: OptimisticNav::ACTIONS } do
      safe_join(@items.map { segment(it) })
    end
  end

  private

  def segment(item)
    link_to item[:name],
            item[:href],
            class: [ITEM_CLASS, item[:current] ? CURRENT_CLASS : OTHER_CLASS],
            'aria-current': ('page' if item[:current])
  end
end
