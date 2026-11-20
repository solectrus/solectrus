# A segmented control on the page: a few pages of the same level side
# by side, the current one raised. Items are hashes with :name, :href and
# :current, as the items of Nav::Sub::Component. It looks the same on white and
# on gray. With `stretch: true`, it takes the full width on a phone, and each
# segment the same part of it, like the switch of a list in its head. An item
# with a :note has a tiny amber dot after its name, like a list with sessions
# to review, and a screen reader reads the note. With `small: true`, it fits
# into the head of a sheet beside the title (see Ui::SheetPage::Component).
class Ui::SegmentedControl::Component < ViewComponent::Base
  ITEM_CLASS =
    'relative rounded-md text-center font-medium whitespace-nowrap focus-ring'.freeze

  # The padding of the bar and the size of a segment, normal and small
  SIZE_CLASSES = {
    normal: { nav: 'rounded-xl p-1.5', item: 'px-4 py-1 text-sm' },
    small: { nav: 'rounded-lg p-1', item: 'px-2.5 py-0.5 text-[0.8125rem]' },
  }.freeze

  CURRENT_CLASS = 'bg-white text-fg shadow-sm dark:bg-slate-600'.freeze

  OTHER_CLASS = 'text-muted'.freeze
  private_constant :ITEM_CLASS, :CURRENT_CLASS, :OTHER_CLASS, :SIZE_CLASSES

  def initialize(items:, label:, stretch: false, small: false)
    super()
    @items = items
    @label = label
    @stretch = stretch
    @size = SIZE_CLASSES[small ? :small : :normal]
  end

  # The raised segment moves to the tapped one at once and slides there, as
  # the period tabs
  def call
    tag.nav class: ['relative inline-flex bg-slate-500/12 dark:bg-slate-800 dark:lg:bg-slate-950/60', @size[:nav], ('max-lg:flex max-lg:w-full' if @stretch)],
            'aria-label': @label,
            data: Ui::OptimisticNav.data(slide: true) do
      safe_join(@items.map { segment(it) })
    end
  end

  private

  def segment(item)
    link_to safe_join([item[:name], dot(item[:note])].compact),
            item[:href],
            class: [ITEM_CLASS, @size[:item], item[:current] ? CURRENT_CLASS : OTHER_CLASS, ('max-lg:flex-1 lg:min-w-28' if @stretch)],
            'aria-current': ('page' if item[:current])
  end

  def dot(note)
    return unless note

    safe_join([tag.span(class: 'inline-block ml-1.5 size-1.5 rounded-full bg-attention-strong align-middle', aria: { hidden: true }), tag.span(", #{note}", class: 'sr-only')])
  end
end
