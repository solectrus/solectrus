class ChartSelector::Component < ViewComponent::Base
  def initialize(sensor:, timeframe:, sensors:)
    super
    @sensor = sensor
    @timeframe = timeframe
    @sensors = sensors.select { |it| it == '-' || SensorConfig.x.exists?(it) }
  end
  attr_reader :sensor, :timeframe, :sensors

  def sensor_items
    sensors.map do |sensor|
      if sensor == '-'
        MenuItem::Component.new(name: '-')
      else
        MenuItem::Component.new(
          name: title(sensor),
          sensor:,
          href:
            url_for(
              controller: "#{helpers.controller_namespace}/home",
              sensor:,
              timeframe:,
            ),
          data: {
            'turbo-frame' => helpers.frame_id('chart'),
            'turbo-action' => 'replace',
            'action' =>
              'stats-with-chart--component#startLoop dropdown--component#toggle',
            'stats-with-chart--component-sensor-param' => sensor,
          },
          current: sensor == @sensor,
        )
      end
    end
  end

  private

  def title(sensor)
    if sensor.in?(%i[autarky self_consumption co2_reduction])
      I18n.t "calculator.#{sensor}"
    else
      SensorConfig.x.name(sensor)
    end
  end
end
