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

      if group_key == :consumer && sensors.length > 7
        # Split consumers into subgroups for desktop column display
        mid_point = (items.length / 2.0).ceil

        groups << {
          name: I18n.t("categories.#{group_key}"),
          subgroups: [
            { items: items[0...mid_point] },
            { items: items[mid_point..] },
          ],
        }
      else
        groups << { name: I18n.t("categories.#{group_key}"), items: }
      end
    end
    groups
  end

  def group_sensors_by_category
    grouped =
      available_sensors
        .group_by { |sensor_name| Sensor::Registry[sensor_name].category }
        .sort_by { |category, _| category_order(category) }
        .to_h

    # Special logic: If there's only one inverter, combine inverter, grid, and battery
    inverter_count = grouped[:inverter]&.length.to_i
    if inverter_count <= 1
      combined = [
        grouped.delete(:inverter),
        grouped.delete(:grid),
        grouped.delete(:battery),
      ].compact.sum([])

      grouped = { generation_grid_battery: combined }.merge(grouped)
    end

    grouped
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
      id: sensor_name,
      href: helpers.url_for(**permitted_params, sensor_name:, only_path: true),
      data: {
        action: 'dropdown--component#toggle',
      },
      sensor_name:,
      current: sensor_name == current_sensor&.name,
    )
  end

  def available_sensors
    @available_sensors ||= Sensor::Config.top10_sensors.map(&:name)
  end

  # Define the order in which categories should appear
  def category_order(category)
    order = {
      inverter: 1,
      grid: 2,
      battery: 3,
      consumer: 4,
      heatpump: 5,
      car: 6,
      economic: 7,
      forecast: 8,
      power_splitter: 9,
      status: 10,
      other: 99,
    }
    order[category] || 100
  end
end
