# The select of the car for the list of the charging sessions: one car,
# "all", and for the wallbox sessions also "not assigned" and "guest". "all"
# shows each session, also a guest session and a session that is not
# assigned. The extras stand apart below the cars, each with an icon.
class ChargingSession::Filter::Component < ViewComponent::Base
  def initialize(kind:, timeframe:, cars:, current:)
    super()
    @kind = kind
    @timeframe = timeframe
    @cars = cars
    @current = current
  end

  attr_reader :kind, :timeframe, :cars, :current

  def render?
    items.size > 2
  end

  def items
    @items ||= [
      item(t('.all'), nil),
      *cars.map { item(it.display_name, it.id.to_s, it.display_color, short_name: it.short_name) },
      *wallbox_items,
    ]
  end

  private

  def wallbox_items
    return [] unless kind == 'wallbox'

    [
      item(t('.unassigned'), CarSelection::UNASSIGNED, leading: task_icon, separator_before: true),
      item(t('.guest'), CarSelection::GUEST, leading: icon('user', class: 'shrink-0 text-slate-400')),
    ]
  end

  # The extras that are an open task have the icon of their hint in the list
  def task_icon = icon('circle-question', class: 'shrink-0 text-amber-500 dark:text-amber-400')

  def item(name, param, color = nil, **)
    MenuItem::Component.new(
      name:,
      href: helpers.cars_charging_sessions_path(kind:, timeframe:, car: param),
      id: param.to_s,
      current: current == param,
      leading: (helpers.car_icon(color) if color),
      **,
    )
  end
end
