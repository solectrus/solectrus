# The state of charge of the home battery and of the one car in use (see
# StatsNow::Component#car), with the plug of the car
class SocBadge::Component < ViewComponent::Base
  def initialize(battery_soc:, car:, car_soc:, car_connected:, time:, timeframe:)
    super()
    @battery_soc = battery_soc
    @car = car
    @car_soc = car_soc
    @car_connected = car_connected
    @time = time
    @timeframe = timeframe
  end
  attr_reader :battery_soc, :car, :car_soc, :car_connected, :time, :timeframe

  def percent
    [battery_soc, car_soc].max
  end

  # The icon of the car fades without a car at the wallbox
  def car_icon_class
    car_connected == false ? 'text-slate-400 dark:text-slate-500' : 'text-slate-500 dark:text-slate-400'
  end

  def color_class(sensor_name, value)
    sensor = Sensor::Registry[sensor_name]
    sensor.color_text(value: value.round) || 'text-slate-500 dark:text-slate-400'
  end
end
