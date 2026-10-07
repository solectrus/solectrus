# Writes the detected sessions of each day: an upsert on the start of a
# session, and the removal of each wallbox session of the day that the new
# result does not contain. It touches only the wallbox sessions of its own
# origin.
#
# A row keeps the holder of an existing row (see #holder) and its note:
#
# - The choice of the user stays: a car, a guest mark or "not assigned". A
#   car stays only when its period holds the day. Otherwise the row gets the
#   car of the rules again.
# - The car that the detection chose before stays when its period holds the
#   day, also when the car has no configuration anymore.
# - A row that is not assigned by the detection gets the car of the rules, so
#   a car reading that arrives late can still assign a session of the
#   current day.
#
# A new build can move a start, so a row that the new result does not
# contain gives its holder and its note to the new session that overlaps it
# most. Without an overlap, these changes are lost.
class ChargingSession::Detection::Persistence
  # Each session of the upsert writes these columns. #merge has put the
  # changes of the user into them already.
  UPDATED_COLUMNS = %i[ended_at kwh kwh_grid cost cost_grid car_id guest assigned_manually note].freeze
  private_constant :UPDATED_COLUMNS

  # The rank of a holder. A holder replaces the holder of a row with the same
  # rank or a lower one, so a guest mark of the user wins over any car, and
  # a choice of the user wins over a choice of the detection.
  RANKS = { detection: 1, user: 2, guest: 3 }.freeze
  private_constant :RANKS

  # results: { date => [ChargingSession::Detection::Session, ...] }
  #
  # One query reads the sessions of all days, and one statement each writes
  # and removes them, so a chunk of days costs no more than one day.
  def call(results)
    return if results.empty?

    existing = existing_by_date(results.keys)
    rows = results.flat_map { |date, sessions| merge(date, sessions, existing.fetch(date, [])) }
    kept = rows.to_set { it[:started_at].to_i }
    removed = existing.values.flatten.reject { kept.include?(it.started_at.to_i) }

    ChargingSession.where(id: removed.map(&:id)).delete_all if removed.any?
    return if rows.empty?

    ChargingSession.upsert_all(
      rows,
      unique_by: :index_charging_sessions_on_wallbox_start,
      update_only: UPDATED_COLUMNS,
    )
  end

  private

  # { local date => [detected wallbox session, ...] } of the given dates
  def existing_by_date(dates)
    ChargingSession
      .wallbox
      .origin_detection
      .where(started_at: dates.map(&:all_day))
      .includes(:car)
      .group_by(&:date)
  end

  def merge(date, sessions, existing)
    # By the second, because a detected time and a stored time are not
    # the same class
    by_start = existing.index_by { it.started_at.to_i }
    rows =
      sessions.map do |session|
        row = session.to_h.merge(kind: 'wallbox', origin: 'detection', guest: false, assigned_manually: false, note: nil)
        old = by_start[session.started_at.to_i]
        old ? keep_holder_and_note(date, row, old) : row
      end

    existing.each do |old|
      next if rows.any? { it[:started_at].to_i == old.started_at.to_i }

      target = rows.max_by { overlap(it, old) }
      keep_holder_and_note(date, target, old) if target && overlap(target, old).positive?
    end

    rows
  end

  def keep_holder_and_note(date, row, old)
    holder = holder(date, old)
    row.merge!(holder.except(:rank)) if holder && holder[:rank] >= rank(row)
    row[:note] = [row[:note], old.note].compact_blank.join("\n").presence
    row
  end

  # The holder of an old row that a new row keeps, or nil
  def holder(date, old)
    if old.assigned_manually?
      return { car_id: nil, guest: true, assigned_manually: true, rank: RANKS[:guest] } if old.guest?
      return { car_id: nil, guest: false, assigned_manually: true, rank: RANKS[:user] } unless old.car

      { car_id: old.car_id, guest: false, assigned_manually: true, rank: RANKS[:user] } if old.car.active_on?(date)
    elsif old.car&.active_on?(date)
      { car_id: old.car_id, guest: false, assigned_manually: false, rank: RANKS[:detection] }
    end
  end

  def rank(row)
    return RANKS[:guest] if row[:guest]

    row[:assigned_manually] ? RANKS[:user] : RANKS[:detection]
  end

  # The overlap of two periods in seconds. A period without a length counts
  # where it lies, so an old row with its start alone still finds its
  # session.
  def overlap(row, old)
    old_end = old.ended_at || old.started_at
    return old.started_at.between?(row[:started_at], row[:ended_at]) ? 1 : 0 if old_end <= old.started_at

    [[row[:ended_at], old_end].min - [row[:started_at], old.started_at].max, 0].max
  end
end
