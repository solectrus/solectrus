class ChartSelector::Component < ViewComponent::Base
  def initialize(
    sensor:,
    timeframe:,
    sensors:,
    top_sensor: nil,
    bottom_sensor: nil
  )
    super()
    @sensor = sensor
    @timeframe = timeframe
    @sensors = sensors.select { |s| SensorConfig.x.exists?(s) }
    @top_sensor = top_sensor
    @bottom_sensor = bottom_sensor
  end
  attr_reader :sensor, :timeframe, :sensors

  def sensor_items
    @sensor_items ||=
      begin
        menu_items =
          sensors.map do |sensor|
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

        menu_items&.sort_by { it.name.downcase }
      end
  end

  def top_sensor
    sensor_items.find { |item| item.sensor == @top_sensor }
  end

  def bottom_sensor
    sensor_items.find { |item| item.sensor == @bottom_sensor }
  end

  private

  def title(sensor)
    if sensor.in?(%i[autarky self_consumption co2_reduction])
      I18n.t "calculator.#{sensor}"
    else
      SensorConfig.x.display_name(sensor, :long)
    end
  end
end
