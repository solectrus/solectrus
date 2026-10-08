module ChargingSessionHelper
  # The cars that can get the session: the cars whose period holds its day.
  # Without a start, a new session offers the cars of the timeframe of the
  # list. The current car stays a choice, also without a configuration, so a
  # form never drops it unseen.
  def car_options(charging_session)
    date = charging_session.started_at&.in_time_zone&.to_date
    cars = date ? car_selection.installed.select { it.active_on?(date) } : car_selection.offered
    current = charging_session.car
    cars = [*cars, current].sort_by(&:id) if current && cars.exclude?(current)

    cars.map { [it.display_name, it.id] }
  end

  # The list of wallbox sessions shows the PV share instead of the address,
  # when the power splitter gives the grid share
  def pv_share_column?(kind)
    kind.to_s == 'wallbox' && Sensor::Config.exists?(:wallbox_power_grid)
  end

  # The start and the end of the session. A session over midnight names the
  # day of its end as well: an offsite session, or a charge at the wallbox
  # (see ChargingSession.joined).
  def charging_session_time_range(charging_session)
    started_at = charging_session.started_at.in_time_zone
    ended_at = charging_session.ended_at&.in_time_zone
    return started_at.strftime('%H:%M') unless ended_at

    time_range(started_at, ended_at) { l(it, format: :short) }
  end

  # Who charged at the own wallbox: a car, a guest, or nobody yet
  def wallbox_holder_options(charging_session)
    [
      *car_options(charging_session).map { |name, id| [name, id.to_s] },
      [t('charging_sessions.guest'), ChargingSession::GUEST],
      [t('charging_sessions.unassigned'), ''],
    ]
  end

  # Who chose the car, the guest mark or "not assigned" of a wallbox session
  def holder_hint(charging_session)
    t(charging_session.assigned_manually? ? 'charging_sessions.form.assigned_manually' : 'charging_sessions.form.assigned_by_detection')
  end
end
