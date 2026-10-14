# A row of a table on the desktop and a cell of a list in the style of iOS on
# a phone. A click anywhere in the row opens its entry, so the row needs no
# edit button. The content is the cells of the row.
#
# One cell renders `row.link`, the link to the entry, around its main value,
# like a date or a name. The keyboard and screen readers reach the entry
# there. The row passes a click on to this link, but not a click on another
# control of the row or one that ends a text selection.
#
# On a phone the link opens the entry on a page of its own, one level down,
# with nav_title as the title of the slide (see Ui::TitleBar::Component). From
# lg up the controller points the link to the modal. A chevron follows the
# cells on a phone. The cells place themselves in the grid of the cell with
# max-lg: classes, see ChargingSession::Row::Component.
#
#   = render Ui::TableRow::Component.new(href: edit_price_path(price), nav_title: 'Edit price') do |row|
#     div = row.link { l(price.starts_at) }
#     div = price.note
class Ui::TableRow::Component < ViewComponent::Base
  # Another link of the row is a target of its own. While the pointer rests on
  # it, the row does not light up, so it shows where a click lands.
  BASE_CLASS =
    'cursor-pointer ' \
    'hover:not-has-[a:not([data-ui--table-row--component-target]):hover]:bg-gray-100 ' \
    'dark:hover:not-has-[a:not([data-ui--table-row--component-target]):hover]:bg-gray-700'.freeze
  private_constant :BASE_CLASS

  # The cell of an iOS list: the separator below it starts where the text
  # starts, and reaches 1px into the next cell, so the card of the list cuts
  # off the separator of the last cell (see Ui::NavList::Component)
  CELL_CLASS =
    'max-lg:relative max-lg:-mb-px max-lg:min-h-12 max-lg:gap-x-3 max-lg:py-2.5 max-lg:px-4 ' \
    'max-lg:active:bg-gray-200 dark:max-lg:active:bg-slate-700/60 ' \
    'max-lg:after:absolute max-lg:after:right-0 max-lg:after:bottom-0 max-lg:after:left-4 max-lg:after:h-px ' \
    'max-lg:after:bg-gray-300/70 dark:max-lg:after:bg-slate-700'.freeze
  private_constant :CELL_CLASS

  LINK_CLASS = 'rounded-sm focus-visible:outline-2 focus-visible:outline-indigo-500'.freeze
  private_constant :LINK_CLASS

  def initialize(href:, nav_title:, css_class: nil)
    super()
    @href = href
    @nav_title = nav_title
    @css_class = css_class
  end

  def call
    tag.div safe_join([content, chevron]),
            class: [@css_class, BASE_CLASS, CELL_CLASS],
            data: {
              controller: 'ui--table-row--component',
              action: 'click->ui--table-row--component#open',
            }
  end

  # No prefetch on hover: the pointer rests on rows all the time
  def link(css_class: nil, &)
    helpers.link_to @href,
                    class: [LINK_CLASS, css_class],
                    data: {
                      nav_title: @nav_title,
                      turbo_prefetch: false,
                      controller: 'modal-launcher',
                      ui__table_row__component_target: 'link',
                    },
                    &
  end

  private

  # The chevron says that the row leads one level down, as in a Ui::NavList. It
  # takes the last column over all rows, so the grid of the cell names its
  # columns and rows.
  def chevron
    icon('chevron-right', class: 'lg:hidden col-end-[-1] row-span-full self-center text-sm text-gray-400 dark:text-slate-500')
  end
end
