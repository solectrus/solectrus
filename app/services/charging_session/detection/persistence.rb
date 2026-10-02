# Writes the detected sessions of each day: an upsert on the start of a
# session, and the removal of each wallbox session of the day that the new
# result does not contain. An offsite session is never touched.
#
# A row keeps the changes of the user. An existing row keeps its car only
# when the period of the car holds the day, and it keeps its guest mark and
# its note. A row that is not assigned gets the car of the rules, so a car
# reading that arrives late can still assign a session of the current day.
# A new build can move a start, so a row that the new result does not
# contain gives its car, its guest mark and its note to the new session that
# overlaps it most. Without an overlap, these changes are lost.
class ChargingSession::Detection::Persistence
  # Each session of the upsert writes these columns. #merge has put the
  # changes of the user into them already.
  UPDATED_COLUMNS = %i[ended_at kwh kwh_grid cost cost_grid car_id guest note].freeze
  private_constant :UPDATED_COLUMNS

  # `assignment` is a ChargingSession::Detection::CarAssignment
  def initialize(assignment)
    @assignment = assignment
  end

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

  attr_reader :assignment

  # { local date => [wallbox session, ...] } of the given dates
  def existing_by_date(dates)
    ChargingSession
      .wallbox
      .where(started_at: dates.map(&:all_day))
      .group_by(&:date)
  end

  def merge(date, sessions, existing)
    # By the second, because a detected time and a stored time are not
    # the same class
    by_start = existing.index_by { it.started_at.to_i }
    rows =
      sessions.map do |session|
        row = session.to_h.merge(kind: 'wallbox', guest: false, note: nil)
        old = by_start[session.started_at.to_i]
        old ? keep_user_changes(date, row, old) : row
      end

    existing.each do |old|
      next if rows.any? { it[:started_at].to_i == old.started_at.to_i }

      target = rows.max_by { overlap(it, old) }
      keep_user_changes(date, target, old) if target && overlap(target, old).positive?
    end

    rows
  end

  # A guest mark wins over the car of another old row, because only the user
  # makes a guest
  def keep_user_changes(date, row, old)
    if old.guest?
      row[:guest] = true
      row[:car_id] = nil
    elsif !row[:guest] && old.car_id && assignment.candidates_on(date).any? { it.id == old.car_id }
      row[:car_id] = old.car_id
    end
    row[:note] = [row[:note], old.note].compact_blank.join("\n").presence
    row
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
