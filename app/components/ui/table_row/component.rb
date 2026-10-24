# A row of a table on the desktop and a cell of a grouped list on a phone. A
# click anywhere in the row opens its entry, so the row needs no
# edit button. The content is the cells of the row.
#
# One cell renders `row.link`, the link to the entry, around its main value,
# like a date or a name. The keyboard and screen readers reach the entry
# there. The row passes a click on to this link, but not a click on another
# control of the row or one that ends a text selection.
#
# On a phone the link opens the entry on a page of its own, one level down,
# with nav_title as the title of the slide (see Ui::TitleBar::Component).
# With `form_sheet: true`, it opens the form of the entry in a sheet instead
# (see FormPageHelper#form_sheet?). From lg up the controller points the
# link to the modal. A chevron follows the cells on a phone. The cells place
# themselves in the grid of the cell with max-lg: classes, see
# ChargingSession::Row::Component.
#
# A row without `href` opens nothing, like a row that a guest may only read.
# It has no hover and no chevron, and `row.link` is its plain content.
#
#   = render Ui::TableRow::Component.new(href: edit_price_path(price), nav_title: 'Edit price') do |row|
#     div = row.link { l(price.starts_at) }
#     div = price.note
class Ui::TableRow::Component < ViewComponent::Base
  # On the desktop the light of a row has round corners, like a menu item.
  # Another link of the row is a target of its own. While the pointer rests on
  # it, the row does not light up, so it shows where a click lands.
  #
  # The keyboard focus on the link marks the whole row, as the row is what
  # the link opens. An outline lies above the cells, a ring would lie below
  # their backgrounds.
  BASE_CLASS =
    'cursor-pointer lg:rounded-lg ' \
    'hover:not-has-[a:not([data-ui--table-row--component-target]):hover]:bg-fill ' \
    'has-[[data-ui--table-row--component-target]:focus-visible]:outline-2 ' \
    'has-[[data-ui--table-row--component-target]:focus-visible]:-outline-offset-2 ' \
    'has-[[data-ui--table-row--component-target]:focus-visible]:outline-indigo-500'.freeze
  private_constant :BASE_CLASS

  # The cell of a grouped list: the separator below it starts where the text
  # starts, and reaches 1px into the next cell, so the card of the list cuts
  # off the separator of the last cell (see Ui::NavList::Component)
  CELL_CLASS =
    'max-lg:relative max-lg:-mb-px max-lg:min-h-12 max-lg:gap-x-3 max-lg:py-2.5 max-lg:px-4 ' \
    'max-lg:active:bg-fill-strong ' \
    'max-lg:after:absolute max-lg:after:right-0 max-lg:after:bottom-0 max-lg:after:left-4 max-lg:after:h-px ' \
    'max-lg:after:bg-line'.freeze
  private_constant :CELL_CLASS

  LINK_CLASS = 'rounded-sm focus:outline-none'.freeze
  private_constant :LINK_CLASS

  def initialize(href:, nav_title: nil, css_class: nil, form_sheet: false)
    super()
    @href = href
    @nav_title = nav_title
    @css_class = css_class
    @form_sheet = form_sheet
  end

  def call
    return tag.div(content, class: [@css_class, CELL_CLASS]) unless @href

    tag.div safe_join([content, chevron]),
            class: [@css_class, BASE_CLASS, CELL_CLASS],
            data: {
              controller: 'ui--table-row--component',
              action: 'click->ui--table-row--component#open',
              ui__table_row__component_form_sheet_value: (true if @form_sheet),
            }.compact
  end

  # No prefetch on hover: the pointer rests on rows all the time
  def link(css_class: nil, &)
    return tag.span(class: css_class, &) unless @href

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
    icon('chevron-right', class: 'lg:hidden col-end-[-1] row-span-full self-center text-sm text-faint')
  end
end
