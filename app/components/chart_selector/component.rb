class ChartSelector::Component < ViewComponent::Base
  def initialize(
    sensor_name:,
    timeframe:,
    sensor_names:,
    top_sensor: nil,
    bottom_sensor: nil
  )
    super()
    raise ArgumentError unless sensor_name.is_a?(Symbol)
    raise ArgumentError unless sensor_names.all?(Symbol)

    @sensor_name = sensor_name
    @timeframe = timeframe
    @sensor_names = sensor_names
    @top_sensor = top_sensor
    @bottom_sensor = bottom_sensor
  end
  attr_reader :sensor_name, :timeframe, :sensor_names

  def sensor_items
    @sensor_items ||=
      begin
        menu_items =
          sensor_names.map do |sensor_name|
            MenuItem::Component.new(
              name: Sensor::Registry[sensor_name].display_name,
              sensor_name:,
              href:
                url_for(
                  controller: "#{helpers.controller_namespace}/home",
                  sensor_name:,
                  timeframe:,
                ),
              data: {
                'turbo-frame' => helpers.frame_id('chart'),
                'turbo-action' => 'replace',
                'action' =>
                  'stats-with-chart--component#startLoop dropdown--component#toggle',
                'stats-with-chart--component-sensor-param' => sensor_name,
              },
              current: sensor_name == @sensor_name,
            )
          end

        menu_items&.sort_by { it.name.downcase }
      end
  end

  def top_sensor
    sensor_items.find { |item| item.sensor_name == @top_sensor }
  end

  def bottom_sensor
    sensor_items.find { |item| item.sensor_name == @bottom_sensor }
  end
end
