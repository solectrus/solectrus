class ChargingSession::Row::Component < ViewComponent::Base
  def initialize(charging_session:)
    super()
    @charging_session = charging_session
  end

  attr_reader :charging_session

  # The day of the session on the power balance
  def day_path
    helpers.balance_home_path(sensor_name: 'wallbox_power', timeframe: charging_session.date.iso8601)
  end

  def pv_share?
    helpers.pv_share_column?(charging_session.kind)
  end

  def time_range
    helpers.charging_session_time_range(charging_session)
  end
end
