class ChartSelector::Component < ViewComponent::Base
  def initialize(sensor:, timeframe:)
    super
    @sensor = sensor
    @timeframe = timeframe
  end
  attr_reader :sensor, :timeframe

  # Sensors available for charting
  def sensor_names
    %i[
      inverter_power
      grid_power
      house_power
      heatpump_power
      wallbox_power
      battery_power
      battery_soc
      car_battery_soc
      case_temp
      autarky
      self_consumption
      co2_reduction
    ].select { |sensor| SensorConfig.x.exists?(sensor) }
    # TODO: Add savings
  end

  def sensor_items
    sensor_names.map do |sensor|
      MenuItem::Component.new(
        name: title(sensor),
        sensor:,
        href: root_path(sensor:, timeframe:),
        data: {
          'turbo-frame' => "chart-#{timeframe}",
          'turbo-action' => 'replace',
          'action' =>
            'stats-with-chart--component#startLoop dropdown--component#toggle',
          'stats-with-chart--component-sensor-param' => sensor,
        },
        current: sensor == @sensor,
      )
    end
  end

  private

  def title(sensor)
    if sensor.in?(%i[autarky self_consumption co2_reduction])
      I18n.t "calculator.#{sensor}"
    else
      I18n.t "sensors.#{sensor}"
    end
  end
end
