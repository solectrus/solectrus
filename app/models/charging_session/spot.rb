# The offsite sessions at one spot of the map of the list (see
# ChargingSession::Map::Component). The sessions in one cell of a grid of a
# thousandth degree, about 100 m, share a spot, so the small moves of a car at
# one station give one spot.
#
# The map loads the cells alone, in one query (see .cells), and the tooltip
# of a spot loads its sessions when the pointer rests on it (see .find). The
# id of a spot is the number of its cell, so both use the same SQL and always
# agree.
ChargingSession::Spot = Data.define(:sessions)

class ChargingSession::Spot
  # The number of the cell of a position: its latitude and its longitude in
  # thousandths of a degree, each one above zero, in one number
  CELL_SQL = '(ROUND(latitude * 1000)::bigint + 90000) * 360001 + ROUND(longitude * 1000)::bigint + 180000'.freeze
  private_constant :CELL_SQL

  # A cell of the map, in the middle of its sessions. The sessions without a
  # position share the cell without an id. A cell with one session knows its
  # id, so the map opens the session at once.
  Cell = Data.define(:id, :latitude, :longitude, :kwh, :count, :session_id)
  public_constant :Cell

  # The cells of the sessions of the scope, the cell with the most energy
  # first, from one query
  def self.cells(scope)
    scope
      .reorder(nil)
      .group(Arel.sql(CELL_SQL))
      .pluck(Arel.sql(CELL_SQL), Arel.sql('AVG(latitude)'), Arel.sql('AVG(longitude)'), Arel.sql('COALESCE(SUM(kwh), 0)'), Arel.sql('COUNT(*)'), Arel.sql('MIN(id)'))
      .map { |row| cell(*row) }
      .sort_by { -it.kwh }
  end

  def self.cell(id, latitude, longitude, kwh, count, session_id)
    Cell.new(id:, latitude: latitude&.round(5), longitude: longitude&.round(5), kwh: kwh.to_f, count:, session_id: (session_id if count == 1))
  end
  private_class_method :cell

  # The spot of the cell, or nil without a session there
  def self.find(scope, id)
    sessions = scope.where("#{CELL_SQL} = ?", Integer(id)).includes(:car).order(started_at: :desc).to_a
    new(sessions:) if sessions.any?
  end

  def kwh = sessions.sum { it.kwh.to_f }

  def cost = sessions.sum { it.cost.to_f }

  # A proposal has no cost before the user confirms it
  def costed? = sessions.all?(&:cost)

  # The name that most sessions of the spot have: the address, the provider
  # or the note. Nil without one, like for a proposal at the position of its
  # car.
  def name
    sessions
      .filter_map { it.address.presence || it.provider.presence || it.note.presence }
      .tally.max_by(&:last)&.first
  end

  # The name in lines. An address breaks at its commas, so its street stands
  # below its town: ["DE-12345 Town", "Main Street 15"]. A provider or a note
  # stays in one line. Empty without a name.
  def name_lines
    name = self.name
    return [] unless name

    sessions.any? { it.address == name } ? name.split(/\s*,\s*/) : [name]
  end

  # The cars of the spot, the car with the most sessions first
  def cars
    sessions.filter_map(&:car).tally.sort_by { -it.last }.map(&:first)
  end
end
