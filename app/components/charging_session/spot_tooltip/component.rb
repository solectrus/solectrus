# The tooltip of a spot on the map of the offsite sessions (see
# ChargingSession::Map::Component). It names the spot, then its sessions, the
# energy and the cost, and the cars that charged there. The map loads it when
# the pointer rests on the spot (see Cars::SpotTooltipsController).
class ChargingSession::SpotTooltip::Component < ViewComponent::Base
  def initialize(spot:)
    super()
    @spot = spot
  end

  attr_reader :spot

  delegate :cars, to: :spot

  def name_lines = spot.name_lines.presence || [t('.unknown_place')]

  # The sessions, the energy and the cost, in one line. A single session
  # shows its day instead of the count.
  def facts
    sessions = spot.sessions
    [
      sessions.one? ? l(sessions.sole.date) : t('.sessions', count: sessions.size),
      render(Sensor::Value::Component.new(spot.kwh * 1000, :wallbox_power, context: :total, scaling: :kilo)),
      (number_to_currency(spot.cost, unit: Currency.symbol) if spot.costed?),
    ].compact
  end
end
