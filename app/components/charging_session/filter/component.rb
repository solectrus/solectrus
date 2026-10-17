# The select of the car for the list of the charging sessions: one car,
# "all", for the wallbox sessions also "not assigned" and "guest", and for
# the offsite sessions also the proposals. "all" shows each session, also a
# guest session, a session that is not assigned and a proposal. The extras
# stand apart below the cars, each with an icon.
#
# The desktop shows it as a menu in the page header. A phone shows it as a
# button above the list, beside the segments of the kinds (layout: :select).
#
# With `views`, the list and the map of the offsite sessions (see
# ChargingSessionsView#view_items), the button holds the view too, as the
# options of the top 10 do: one menu with a group for the view and one for
# the car. The button shows the current car with its icon, as without views.
# The content below shows the view, so the button does not.
class ChargingSession::Filter::Component < ViewComponent::Base
  # `view` is the map or nil for the list, which each car keeps (see
  # ChargingSessionsView)
  def initialize(kind:, timeframe:, cars:, current:, layout: :menu, view: nil, views: nil) # rubocop:disable Metrics/ParameterLists
    super()
    @layout = layout
    @kind = kind
    @timeframe = timeframe
    @cars = cars
    @current = current
    @view = view
    @views = views
  end

  attr_reader :kind, :timeframe, :cars, :current, :views

  def select? = @layout == :select

  def render?
    views.present? || choice_of_car?
  end

  # A single car leaves "all" and the car, which show the same sessions
  def choice_of_car? = items.size > 2

  def groups
    [view_group, ({ name: t('.car'), items: } if choice_of_car?)].compact
  end

  # The proposals without the detection have no item
  def display_name
    return t('.options') unless current_item

    tag.span class: 'flex items-center gap-2' do
      safe_join([current_item.leading, current_item.short_name || current_item.name].compact)
    end
  end

  def items
    @items ||= [
      item(t('.all'), nil, short_name: (t('.all_short') if select?), leading: (menu_icon('layer-group') if views)),
      *cars.map { item(it.display_name, it.id.to_s, it.display_color, short_name: it.short_name) },
      *wallbox_items,
      *offsite_items,
    ]
  end

  # The white button above the list of a phone, or the button on the colored
  # bar of the page header
  def dropdown_options
    select? ? Ui::Dropdown::Component.pill_options : { button_class: Ui::Dropdown::Component::HEADER_BUTTON_CLASS }
  end

  private

  def view_group
    {
      name: t('.view'),
      items:
        views.map do |view|
          Ui::MenuItem::Component.new(
            name: view[:name],
            href: view[:href],
            id: view[:icon],
            current: view[:current],
            leading: menu_icon(view[:icon]),
          )
        end,
    }
  end

  # The views and "all" have an icon in the width of the icon of a car, so
  # the names stand in one column with the cars, as in Car::Select::Component
  def menu_icon(name) = icon(name, class: 'shrink-0 w-[1.25em] opacity-60')

  def current_item = items.find(&:current)

  def wallbox_items
    return [] unless kind == 'wallbox'

    [
      item(t('.unassigned'), CarSelection::UNASSIGNED, leading: task_icon, separator_before: true),
      item(t('.guest'), CarSelection::GUEST, leading: icon('user', class: 'shrink-0 text-slate-400')),
    ]
  end

  # Without a state of charge, the build makes no proposal
  def offsite_items
    return [] unless kind == 'offsite' && ChargingSession::OffsiteDetection.enabled?

    short_name = t('charging_sessions.proposal.name') if select?
    [item(t('.proposals'), CarSelection::PROPOSALS, leading: task_icon, separator_before: true, short_name:)]
  end

  # The extras that are an open task have the icon of their hint in the list
  def task_icon = icon('circle-question', class: 'shrink-0 text-amber-500 dark:text-amber-400')

  def item(name, param, color = nil, **)
    Ui::MenuItem::Component.new(
      name:,
      href: helpers.cars_charging_sessions_path(kind:, timeframe:, car: param, view: @view),
      id: param.to_s,
      current: current == param,
      leading: (helpers.car_icon(color) if color),
      **,
    )
  end
end
