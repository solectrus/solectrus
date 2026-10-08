class ChargingSession::Row::Component < ViewComponent::Base
  def initialize(charging_session:)
    super()
    @charging_session = charging_session
  end

  attr_reader :charging_session

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
end
