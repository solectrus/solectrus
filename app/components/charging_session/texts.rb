# The time and the state of charge of a charging session as text. Shared by
# the row of the list, the facts of the form and the state of charge, which
# all read `charging_session`.
module ChargingSession::Texts
  extend ActiveSupport::Concern
  include TimeRangeText

  # The start and the end of the session. A session over midnight names the
  # day of its end as well: an offsite session, or a charge at the wallbox
  # (see ChargingSession.joined). An ongoing session has no end yet.
  def time_range
    started_at = charging_session.started_at.in_time_zone
    if charging_session.ongoing?
      return t('charging_sessions.since', time: started_at.today? ? started_at.strftime('%H:%M') : l(started_at, format: :short))
    end

    ended_at = charging_session.ended_at&.in_time_zone
    return started_at.strftime('%H:%M') unless ended_at

    time_range_text(started_at, ended_at) { l(it, format: :short) }
  end

  # The state of charge at the start and at the end: "23 -> 81 %", or nil. An
  # ongoing session has only its start: "from 23 %".
  def soc_range
    if charging_session.ongoing?
      return unless charging_session.soc_from

      return t('charging_sessions.soc_from', percent: number_to_percentage(charging_session.soc_from.round, precision: 0))
    end
    return unless charging_session.soc_from && charging_session.soc_to

    "#{charging_session.soc_from.round} → #{number_to_percentage(charging_session.soc_to.round, precision: 0)}"
  end
end
