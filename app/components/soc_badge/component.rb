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

  def color_class(sensor_name, value)
    sensor = Sensor::Registry[sensor_name]
    sensor.color_text(value: value.round) || 'text-slate-500 dark:text-slate-400'
  end
end
