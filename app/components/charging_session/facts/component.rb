# The facts of a wallbox session the detection writes: the time, the energy,
# its PV share, the cost, the state of charge and the loss. The form shows
# them read-only above its fields.
class ChargingSession::Facts::Component < ViewComponent::Base
  def initialize(charging_session:)
    super()
    @charging_session = charging_session
  end

  attr_reader :charging_session

  def started_at
    charging_session.started_at.in_time_zone
  end

  def date
    l(started_at.to_date, format: :long)
  end

  def time_range
    helpers.charging_session_time_range(charging_session)
  end
end
