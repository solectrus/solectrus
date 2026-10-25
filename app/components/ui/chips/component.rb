# A row of chips: the choices of a filter of the page, all in view, the
# current one filled. A tap on a chip leads to its page. Items are hashes
# with :name, :href and :current, and an optional :leading, like an icon
# before the name. The row stands in the middle. A row wider than the screen
# scrolls sideways and reaches to the edges of the screen.
#
# The marking moves to the tapped chip at once. The page with the other
# choice is the same page with another filter, so its content stays in view
# until the next page renders (see setupSamePageVisits.ts).
class Ui::Chips::Component < ViewComponent::Base
  ITEM_CLASS =
    'relative flex shrink-0 items-center gap-1.5 h-8 rounded-full px-3 text-sm font-medium whitespace-nowrap touch-target click-animation focus-ring'.freeze

  CURRENT_CLASS = 'bg-indigo-50 text-indigo-700 ring-1 ring-inset ring-indigo-200 dark:bg-indigo-400/15 dark:text-indigo-200 dark:ring-indigo-400/30'.freeze

  OTHER_CLASS = 'bg-fill text-fg'.freeze
  private_constant :ITEM_CLASS, :CURRENT_CLASS, :OTHER_CLASS

  # `replace: true` replaces the entry of the browser history, so the way
  # back leaves the page instead of going through each choice
  def initialize(items:, label:, replace: false)
    super()
    @items = items
    @label = label
    @replace = replace
  end

  # The row stands in the middle. Its auto margins drop to nothing once it is
  # wider than the screen, so it scrolls from its first chip.
  def call
    tag.nav class: '-mx-4 flex overflow-x-auto px-4 py-1.5 [scrollbar-width:none]', 'aria-label': @label do
      tag.div class: 'mx-auto flex gap-2', data: { controller: 'optimistic-nav', action: OptimisticNav::ACTIONS } do
        safe_join(@items.map { chip(it) })
      end
    end
  end

  private

  def chip(item)
    link_to safe_join([item[:leading], item[:name]].compact),
            item[:href],
            class: [ITEM_CLASS, item[:current] ? CURRENT_CLASS : OTHER_CLASS],
            'aria-current': ('page' if item[:current]),
            data: { same_page: true, turbo_action: ('replace' if @replace) }.compact
  end
end
