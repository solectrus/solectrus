# The choices and the buttons of the form of a charging session
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

  # The button of the form that takes a session from the list. A proposal is
  # dismissed, so the next build does not make it again. An offsite session
  # of the user is deleted. A wallbox session stays, the detection owns it.
  def charging_session_removal(charging_session)
    if charging_session.proposal?
      {
        delete_path: dismiss_cars_charging_session_path(charging_session),
        removal: {
          method: :patch,
          label: t('charging_sessions.proposal.dismiss'),
          confirm: t('charging_sessions.proposal.confirm_dismiss'),
          icon: 'xmark',
        },
      }
    elsif charging_session.offsite? && charging_session.persisted?
      { delete_path: cars_charging_session_path(charging_session) }
    else
      {}
    end
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
