# The select of the car above the list of the charging sessions: one car,
# "all", and for the wallbox sessions also "not assigned" and "guest". "all"
# shows each session, also a guest session and a session that is not
# assigned.
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
      *cars.map { item(it.display_name, it.id.to_s, it.display_color) },
      *wallbox_items,
    ]
  end

  private

  def wallbox_items
    return [] unless kind == 'wallbox'

    [
      item(t('.not_assigned'), ChargingSessionList::CarFilter::NOT_ASSIGNED),
      item(t('.guest'), ChargingSessionList::CarFilter::GUEST),
    ]
  end

  def item(label, param, color = nil)
    PillNav::Component::Item.new(
      label:,
      href: helpers.charging_sessions_path(kind:, timeframe:, car: param),
      current: current == param,
      color:,
    )
  end
end
