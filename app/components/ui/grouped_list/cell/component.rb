# One cell of a Ui::GroupedList::Component: an icon, the name and, at the
# right, a badge, a dot, a control or an icon that tells where a tap leads.
#
# With href, the cell is a link. A link to another site opens in a new tab
# and shows an arrow out of a box, a link inside the app shows a chevron.
# `external: true` shows that arrow for a link of the app that leads to
# another site. `slide: true` slides to a page with a Ui::TitleBar::Component
# that leads back here (see docs/ui.md), `plain: true` when that page keeps
# its own background. Without href, the cell is a button, and `data`
# names its action. With an accessory, the cell holds that control and does
# not react to a tap itself.
#
# `row_data` goes to the row itself, so a rule can hide the whole row,
# separator included. `destructive: true` paints the name red, like a logout.
# `detail` is a second, smaller line below the name, like a reason why a
# control is not available.
class Ui::GroupedList::Cell::Component < ViewComponent::Base
  renders_one :accessory

  ROW_CLASS = 'flex w-full items-center gap-3 pl-4 text-left'.freeze
  TAP_CLASS =
    'active:bg-gray-200 dark:active:bg-slate-700/60 pointer-fine:hover:bg-gray-200/60 ' \
    'dark:pointer-fine:hover:bg-slate-700/40 focus-ring-inset cursor-pointer'.freeze
  private_constant :ROW_CLASS, :TAP_CLASS

  def initialize( # rubocop:disable Metrics/ParameterLists
    name:,
    icon: nil,
    href: nil,
    data: {},
    row_data: {},
    slide: false,
    plain: false,
    external: nil,
    badge_count: nil,
    dot: false,
    destructive: false,
    detail: nil
  )
    super()
    @name = name
    @detail = detail
    @icon_name = icon
    @href = href
    @data = data
    @row_data = row_data
    @slide = slide
    @plain = plain
    @external = external
    @badge_count = badge_count
    @dot = dot
    @destructive = destructive
  end

  attr_reader :name, :icon_name, :row_data, :badge_count, :dot, :detail

  def tag_name
    if @href
      :a
    else
      (accessory? ? :div : :button)
    end
  end

  def tag_options
    case tag_name
    when :a
      {
        href: @href,
        class: [ROW_CLASS, TAP_CLASS],
        data: link_data,
        target: ('_blank' if other_site?),
        rel: ('noopener' if other_site?),
      }
    when :button
      { type: 'button', class: [ROW_CLASS, TAP_CLASS], data: @data }
    else
      { class: ROW_CLASS }
    end
  end

  def name_class
    @destructive ? 'text-signal-negative' : 'text-gray-800 dark:text-slate-300'
  end

  # Where a tap leads: out of the app, or one level down. A destructive cell
  # runs an action and leads nowhere.
  def trailing_icon
    return if @href.nil? || @destructive

    leaves_app? ? 'arrow-up-right-from-square' : 'chevron-right'
  end

  # The chevron says that the cell leads one level down, which only a phone
  # shows as a slide. The desktop has the hover instead.
  def trailing_icon_class
    ['text-sm text-gray-400 dark:text-slate-500', ('lg:hidden' unless leaves_app?)]
  end

  private

  def leaves_app?
    @external || other_site?
  end

  def other_site?
    @href.start_with?('http')
  end

  def link_data
    @slide ? @data.merge(Ui::TitleBar::Component.link_data(name, plain: @plain)) : @data
  end
end
