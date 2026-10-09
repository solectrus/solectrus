# Gives each offsite session that the user entered the state of charge and
# the position of its rise (see ChargingSession::OffsiteDetection). A wrong
# value is worse than none, so a session gets them only when its rise is
# clear. The sessions find their rises in three stages, and each stage
# leaves out the rises that an earlier stage found:
#
# 1. A session with an end takes the rises in its time.
# 2. A session with an end and no rise in its time takes the rises in its
#    time with ChargingSession::Proposal::BLOCK_MARGIN around it, because an
#    entered time is not exact.
# 3. A session without an end takes the rises of its day.
#
# In each stage, a session gets a rise when it finds exactly one rise and no
# other session finds this rise. Otherwise its values stay empty. Two stops
# on one trip thus get a rise each, and the session of the day gets only the
# rise that no stop takes.
class ChargingSession::OffsiteDetection::EnteredState
  # The values of a rise that a session gets
  COLUMNS = %i[soc_from soc_to latitude longitude].freeze
  private_constant :COLUMNS

  # `sessions` are the entered sessions of the days of the step, `rises` the
  # rises of these days away from the wallbox
  def initialize(sessions, rises)
    @sessions = sessions
    @rises = rises
  end

  def call
    timed, untimed = sessions.partition(&:ended_at)
    claimed = []
    found = {}

    in_time = stage(timed, claimed, found) { |session, rise| rise.car_id == session.car_id && rise.overlap?(session.started_at, session.ended_at) }
    stage(timed - in_time.keys, claimed, found) { |session, rise| rise.blocked_by?(session) }
    stage(untimed, claimed, found) { |session, rise| rise.blocked_by?(session) }

    sessions.each { write(it, found[it]) }
  end

  private

  attr_reader :sessions, :rises

  # { session => [rise, ...] } of the sessions of a stage that find a rise
  # that no earlier stage found. It adds the clear ones to `found` and their
  # rises to `claimed`.
  def stage(stage_sessions, claimed, found, &)
    matches = stage_sessions.index_with { |session| (rises - claimed).select { yield(session, it) } }.select { |_, candidates| candidates.any? }
    matches.each { |session, candidates| found[session] = candidates.first if clear?(candidates, matches) }
    claimed.concat(matches.values.flatten)
    matches
  end

  # Whether a session found one rise that no other session of its stage found
  def clear?(candidates, matches)
    candidates.one? && matches.values.one? { it.include?(candidates.first) }
  end

  # Writes a session only when a value changes
  def write(session, rise)
    values = COLUMNS.index_with { rise&.public_send(it) }
    return if values.all? { |key, value| session[key]&.to_f == value&.to_f }

    session.update_columns(values) # rubocop:disable Rails/SkipsModelValidations
  end
end
