# A segmented control on the page: a few pages of the same level side
# by side, the current one raised. Items are hashes with :name, :href and
# :current, as the items of Nav::Sub::Component. It looks the same on white and
# on gray. With `stretch: true`, it takes the full width on a phone, and each
# segment the same part of it, like the switch of a list in its head. An item
# with a :note has a tiny amber dot after its name, like a list with sessions
# to review, and a screen reader reads the note.
class Ui::SegmentedControl::Component < ViewComponent::Base
  ITEM_CLASS =
    'relative rounded-md px-4 py-1 text-center text-sm font-medium whitespace-nowrap focus-ring'.freeze

  CURRENT_CLASS = 'bg-white text-fg shadow-sm dark:bg-slate-600'.freeze

  OTHER_CLASS = 'text-muted'.freeze
  private_constant :ITEM_CLASS, :CURRENT_CLASS, :OTHER_CLASS

  def initialize(items:, label:, stretch: false)
    super()
    @items = items
    @label = label
    @stretch = stretch
  end

  # The raised segment moves to the tapped one at once and slides there, as
  # the period tabs
  def call
    tag.nav class: ['relative inline-flex rounded-xl bg-slate-500/12 p-1.5 dark:bg-slate-800 dark:lg:bg-slate-950/60', ('max-lg:flex max-lg:w-full' if @stretch)],
            'aria-label': @label,
            data: { controller: 'optimistic-nav', optimistic_nav_slide_value: true, action: OptimisticNav::ACTIONS } do
      safe_join(@items.map { segment(it) })
    end
  end

  private

  def segment(item)
    link_to safe_join([item[:name], dot(item[:note])].compact),
            item[:href],
            class: [ITEM_CLASS, item[:current] ? CURRENT_CLASS : OTHER_CLASS, ('max-lg:flex-1 lg:min-w-28' if @stretch)],
            'aria-current': ('page' if item[:current])
  end

  def dot(note)
    return unless note

    safe_join([tag.span(class: 'inline-block ml-1.5 size-1.5 rounded-full bg-attention-strong align-middle', aria: { hidden: true }), tag.span(", #{note}", class: 'sr-only')])
  end
end
