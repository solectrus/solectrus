class ChargingSession::Row::Component < ViewComponent::Base
  # `place` is the known place at the position of a session without an
  # address (see ChargingSession::Rows::Component)
  def initialize(charging_session:, place: nil)
    super()
    @charging_session = charging_session
    @place = place
  end

  attr_reader :charging_session, :place

  # Where the session charged: its address, the known place at its position,
  # its provider or its note
  def location
    charging_session.address.presence || place&.display_name || charging_session.provider.presence || charging_session.note
  end

  # The day of the session: on the car page for the session of a car, and on
  # the power balance for the wallbox otherwise
  def day_path
    day = charging_session.date.iso8601
    if charging_session.car
      helpers.cars_home_path(sensor_name: 'car_charging', timeframe: day, car: charging_session.car_id)
    else
      helpers.balance_home_path(sensor_name: 'wallbox_power', timeframe: day)
    end
  end

  def pv_share?
    helpers.pv_share_column?(charging_session.kind)
  end

  def time_range
    helpers.charging_session_time_range(charging_session)
  end

  def soc_range
    helpers.charging_session_soc_range(charging_session)
  end
end
