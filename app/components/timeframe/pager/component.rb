# The period of a phone, at the top of the content of its page: its name
# between two arrows. The tabs in the header pick the kind of period (see
# Nav::Sub::Component), this row turns it. A tap on the name opens the
# timeframe select in the sheet. The arrows turn the page, and so does a swipe
# (see swipe_controller.ts).
#
# `period` is a hash with :name and :href, the address of the page in its
# period, or nil on the live view and on a comparison of the years. Without a
# period, the row does not show, but keeps its arrows hidden, as the swipe
# takes its pages from them. `arrows` has the
# pages before and after this one as :prev and :next. A missing one has none.
class Timeframe::Pager::Component < ViewComponent::Base
  # The place of the row, which the status of the live view takes as well, so
  # the content does not move between the tabs (see shared/_home_sub_nav)
  ROW_CLASS = '-mt-4 mb-2 h-11'.freeze
  public_constant :ROW_CLASS

  def initialize(period:, arrows:)
    super()
    @period = period
    @arrows = arrows
  end

  attr_reader :period, :arrows

  # An arrow without a page in its direction keeps its place, dimmed, so the
  # name does not move. Its link gives the swipe its page (`data-nav`). The
  # arrow takes the height of a tap target.
  def arrow(direction)
    icon = helpers.icon(direction == :prev ? 'chevron-left' : 'chevron-right', class: 'fa-lg')
    classes = 'flex items-center justify-center size-11'
    href = arrows[direction]
    return tag.span(icon, class: [classes, 'opacity-30'], 'aria-hidden': true) unless href

    link_to icon, href, class: [classes, 'click-animation'], 'aria-label': t(".#{direction}"), data: { nav: direction }
  end

  def select_href = TimeframeSelectModal.path(period[:href])
end
