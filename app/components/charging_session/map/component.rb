# The offsite sessions of the list on a map, the other view of the list (see
# ChargingSessionsView). A circle marks a spot where the cars charged, and its
# area shows the share of the energy (see ChargingSession::Spot). The page
# carries only the circles, and the map loads the tooltip of a spot when the
# pointer rests on it. A session without a position is missing, and a note on
# the map counts these sessions.
class ChargingSession::Map::Component < ViewComponent::Base
  # `scope` holds the sessions of the list, `tooltip_url` the tooltip of a
  # spot with ":id" for its id (see Cars::SpotTooltipsController)
  def initialize(scope:, tooltip_url:)
    super()
    @scope = scope
    @tooltip_url = tooltip_url
  end

  attr_reader :tooltip_url

  # Whether the list has a session, with or without a position
  delegate :any?, to: :cells

  def located? = located.any?

  # [[latitude, longitude, share of the energy, id, href], ...] (see
  # Car::Map::Component). A spot with one session links to its form, which
  # keeps the address of the map, like a row of the list.
  def places
    total = located.sum(&:kwh)
    located.map do |cell|
      [cell.latitude, cell.longitude, total.positive? ? cell.kwh.fdiv(total).round(4) : 0, cell.id, edit_path(cell)].compact
    end
  end

  def unlocated_count = cells.find { it.id.nil? }&.count.to_i

  private

  def cells = @cells ||= ChargingSession::Spot.cells(@scope)

  def located = cells.select(&:id)

  def edit_path(cell)
    helpers.edit_cars_charging_session_path(cell.session_id, return_to: helpers.list_address) if cell.session_id
  end
end
