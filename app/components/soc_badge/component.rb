class SocBadge::Component < ViewComponent::Base
  def initialize(
    battery_soc:,
    car_battery_soc:,
    time:,
    timeframe:,
    car_connected:
  )
    super()
    @battery_soc = battery_soc
    @car_battery_soc = car_battery_soc
    @time = time
    @timeframe = timeframe
    @car_connected = car_connected
  end
  attr_reader :battery_soc, :car_battery_soc, :time, :timeframe, :car_connected

  def percent
    [battery_soc, car_battery_soc].compact.max
  end
end
