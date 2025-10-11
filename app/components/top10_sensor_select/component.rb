class Top10SensorSelect::Component < ViewComponent::Base
  def initialize(current_sensor:, permitted_params:)
    super()
    @current_sensor = current_sensor
    @permitted_params = permitted_params
  end

  attr_reader :current_sensor, :permitted_params

  def sensor_groups
    @sensor_groups ||= build_grouped_sensor_items
  end

  private

  def build_grouped_sensor_items
    build_menu_groups(group_sensors_by_category)
  end

  def build_menu_groups(sensor_groups)
    groups = []
    sensor_groups.each do |group_key, sensors|
      next if sensors.none?

      items = build_menu_items_for_sensors(sensors)

      if group_key == :consumers && sensors.length > 7
        # Split consumers into subgroups for desktop column display
        mid_point = (items.length / 2.0).ceil

        groups << {
          name: t(".groups.#{group_key}"),
          subgroups: [
            { items: items[0...mid_point] },
            { items: items[mid_point..] },
          ],
        }
      else
        groups << { name: t(".groups.#{group_key}"), items: items }
      end
    end
    groups
  end

  def group_sensors_by_category
    if generation_sensors.length <= 1
      {
        generation_grid_battery: generation_sensors + grid_battery_sensors,
        consumers: consumer_sensors,
        other: other_sensors,
      }
    else
      {
        generation: generation_sensors,
        grid_battery: grid_battery_sensors,
        consumers: consumer_sensors,
        other: other_sensors,
      }
    end
  end

  def build_menu_items_for_sensors(sensors)
    sensors
      .map { |sensor_name| build_menu_item(sensor_name) }
      .sort_by do |item|
        Sensor::Registry[item.sensor_name].display_name(:long).downcase
      end
  end

  def build_menu_item(sensor_name)
    MenuItem::Component.new(
      name: Sensor::Registry[sensor_name].display_name(:long),
      href: helpers.url_for(**permitted_params, sensor_name:, only_path: true),
      data: {
        action: 'dropdown--component#toggle',
      },
      sensor_name:,
      current: sensor_name == current_sensor&.name,
    )
  end

  # Categories

  def generation_sensors
    @generation_sensors ||= Sensor::Config.inverter_sensors.map(&:name)
  end

  def grid_battery_sensors
    @grid_battery_sensors ||=
      available_sensors.select do |sensor|
        sensor.in?(
          %i[
            grid_import_power
            grid_export_power
            battery_charging_power
            battery_discharging_power
          ],
        )
      end
  end

  def consumer_sensors
    @consumer_sensors ||=
      available_sensors.select do |sensor|
        sensor.in?(
          Sensor::Config.custom_power_sensors.map(&:name) +
            %i[house_power heatpump_power wallbox_power],
        )
      end
  end

  def other_sensors
    @other_sensors ||=
      available_sensors -
        (generation_sensors + grid_battery_sensors + consumer_sensors)
  end

  def available_sensors
    @available_sensors ||= Sensor::Config.top10_sensors.map(&:name)
  end
end
