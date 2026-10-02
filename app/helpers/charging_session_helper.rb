module ChargingSessionHelper
  # The cars that can get the session: the cars whose period holds its day.
  # The current car stays a choice, so a form never drops it unseen.
  def car_options(charging_session)
    date = charging_session.started_at&.in_time_zone&.to_date || Date.current
    cars
      .select { it.active_on?(date) || it.id == charging_session.car_id }
      .map { [it.display_name, it.id] }
  end

  # The list of wallbox sessions shows the PV share instead of the address,
  # when the power splitter gives the grid share
  def pv_share_column?(kind)
    kind.to_s == 'wallbox' && Sensor::Config.exists?(:wallbox_power_grid)
  end

  # The start and the end of the session. A session over midnight names the
  # day of its end as well, which only an offsite session can have.
  def charging_session_time_range(charging_session)
    started_at = charging_session.started_at.in_time_zone
    ended_at = charging_session.ended_at&.in_time_zone
    from = started_at.strftime('%H:%M')
    return from unless ended_at
    return "#{from}–#{ended_at.strftime('%H:%M')}" if ended_at.to_date == started_at.to_date

    "#{from} – #{l(ended_at, format: :short)}"
  end

  # Who charged at the own wallbox: a car, a guest, or nobody yet
  def wallbox_holder_options(charging_session)
    [
      *car_options(charging_session).map { |name, id| [name, id.to_s] },
      [t('charging_sessions.guest'), ChargingSessionList::CarFilter::GUEST],
      [t('charging_sessions.not_assigned'), ''],
    ]
  end
end
