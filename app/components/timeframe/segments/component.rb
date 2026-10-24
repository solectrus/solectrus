# The timeframe of a phone in one row, in the look of the tabs (see
# Nav::TabLook): the live view, the period of the page and today in one bar.
# The period lies before today, so the arrow back from today marks the
# segment to its left. Each one is a hash with :name, :href and :current,
# and each leads to its page. Once the period is the current one, it carries
# a chevron and opens the timeframe select in the sheet instead, so a tap from
# the live view or today never lands in the sheet. A long press on the period
# opens the sheet in either case (see component_controller.ts). The arrows at
# the ends of the row turn the page, and so does a swipe (see
# swipe_controller.ts).
class Timeframe::Segments::Component < ViewComponent::Base
  include Nav::TabLook

  # `arrows` has the pages before and after this one as :prev and :next. A
  # missing one has none.
  def initialize(live:, today:, period:, arrows:)
    super()
    @live = live
    @today = today
    @period = period
    @arrows = arrows
  end

  attr_reader :live, :today, :period, :arrows

  BAR_CLASSES = 'row-start-1 rounded-lg bg-black/15 dark:bg-black/25'.freeze
  private_constant :BAR_CLASSES

  # An arrow without a page in its direction keeps its place, dimmed, so the
  # row does not move. It sits in a span, as optimistic-nav takes a link of
  # the nav itself for a segment. Each arrow stands at its end of the row.
  # Its link gives the swipe its page (`data-nav`).
  def arrow(direction, href, column:)
    icon = helpers.icon(direction == :prev ? 'chevron-left' : 'chevron-right')
    classes = ['flex flex-1 items-center', direction == :prev ? 'justify-start' : 'justify-end']
    arrow =
      if href
        link_to icon, href, class: [*classes, '[&.is-pressed]:opacity-50 transition-opacity'], 'aria-label': t(".#{direction}"), data: { nav: direction }
      else
        tag.span(icon, class: [*classes, 'opacity-30'], 'aria-hidden': true)
      end

    tag.span(arrow, class: 'row-start-1 flex text-white dark:text-slate-300', style: "grid-column: #{column}")
  end

  def segment(item, column:) = link_to(item[:name], item[:href], **segment_options(item, column:))

  # The layout is the same for each segment: optimistic-nav swaps the class
  # lists of the segment it leaves and of the tapped one. The column stays.
  def segment_options(item, column:)
    {
      class: segment_classes(item),
      style: "grid-column: #{column}",
      'aria-current': aria_current(item),
    }
  end

  # The current period opens the sheet. Any other leads to its page. A long
  # press opens the sheet in either case (see component_controller.ts).
  def period_options
    long_press = { controller: 'timeframe--segments--component', action: LONG_PRESS_ACTIONS, 'timeframe--segments--component-href-value': select_href }
    options = segment_options(period, column: 3)
    return options.merge(data: long_press) unless period[:current]

    options.merge(
      'aria-haspopup': 'dialog',
      data: { **long_press, turbo_frame: 'modal', controller: "modal-launcher #{long_press[:controller]}" },
    )
  end

  def period_href = period[:current] ? select_href : period[:href]

  LONG_PRESS_ACTIONS = %w[
    pointerdown->timeframe--segments--component#down
    pointermove->timeframe--segments--component#move
    pointerup->timeframe--segments--component#cancel
    pointercancel->timeframe--segments--component#cancel
    click->timeframe--segments--component#click
    contextmenu->timeframe--segments--component#contextmenu
  ].join(' ').freeze
  private_constant :LONG_PRESS_ACTIONS

  private

  def select_href = @select_href ||= TimeframeSelectModal.path(period[:href])

  def segment_classes(item)
    base_classes + %w[row-start-1 m-0.5 min-w-0 flex items-center justify-center] + (item[:current] ? current_classes : idle_classes)
  end

  def aria_current(item) = ('page' if item[:current])
end
