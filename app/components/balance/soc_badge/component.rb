# The state of charge of the home battery and of the one car in use (see
# Balance::StatsNow::Component#car), with the plug of the car
class Balance::SocBadge::Component < ViewComponent::Base
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

  def car_sensor_name = car.sensor_name(:car_battery_soc)

  # A tap loads the chart of the state of charge, like any value of the
  # power balance
  def chart_data(sensor_name, value)
    {
      turbo_prefetch: 'false',
      'stats-with-chart--component-target': 'current',
      'sensor-name': sensor_name,
      value:,
      time: time.to_i,
      action: 'stats-with-chart--component#loadChart',
      stats_with_chart__component_sensor_name_param: sensor_name,
      stats_with_chart__component_chart_url_param: balance_charts_path(sensor_name:, timeframe:),
    }
  end

  def color_class(sensor_name, value)
    sensor = Sensor::Registry[sensor_name]
    sensor.color_text(value: value.round) || 'text-slate-500 dark:text-slate-400'
  end
end
