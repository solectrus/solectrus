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
      case_temp
      autarky
      consumption
    ].select do |sensor|
      Rails.application.config.x.influx.sensors.exists?(sensor)
    end
    # TODO: Add savings and co2_savings
  end

  def sensor_items
    sensor_names.map do |sensor|
      MenuItem::Component.new(
        name: title(sensor),
        sensor:,
        href: root_path(sensor:, timeframe:),
        data: {
          'turbo-frame' => 'chart',
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
    if sensor.in?(%i[battery_soc])
      "#{I18n.t "sensors.#{sensor}"} in &percnt;".html_safe
    elsif sensor.in?(%i[autarky consumption])
      "#{I18n.t "calculator.#{sensor}"} in &percnt;".html_safe
    elsif sensor.in?(%i[case_temp])
      "#{I18n.t "sensors.#{sensor}"} in &deg;C".html_safe
    else
      "#{I18n.t "sensors.#{sensor}"} in #{power? ? 'kW' : 'kWh'}"
    end
  end

  def power?
    timeframe.now? || timeframe.day?
  end
end
