class ChartSelector::Component < ViewComponent::Base # rubocop:disable Metrics/ClassLength
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

  def display_name
    # For individual sensors that are part of a combined chart,
    # show the main sensor with the other one in parentheses
    case sensor_name
    when :grid_import_power
      "#{Sensor::Registry[:grid_import_power].display_name} (& #{Sensor::Registry[:grid_export_power].display_name})"
    when :grid_export_power
      "#{Sensor::Registry[:grid_export_power].display_name} (& #{Sensor::Registry[:grid_import_power].display_name})"
    when :battery_charging_power
      "#{Sensor::Registry[:battery_charging_power].display_name} (& #{Sensor::Registry[:battery_discharging_power].display_name})"
    when :battery_discharging_power
      "#{Sensor::Registry[:battery_discharging_power].display_name} (& #{Sensor::Registry[:battery_charging_power].display_name})"
    else
      Sensor::Registry[sensor_name]&.display_name
    end
  end

  def sensor_groups
    @sensor_groups ||= build_grouped_sensor_items
  end

  def grouped?
    sensor_groups.length > 1
  end

  def sensor_items
    # If not grouped, return flat array of items
    return [] if sensor_groups.empty?

    sensor_groups.first&.dig(:items) || []
  end

  def top_sensor
    all_items =
      if grouped?
        sensor_groups.flat_map { |group| group[:items] || [] }
      else
        sensor_items
      end
    all_items.find { |item| item.sensor_name == @top_sensor }
  end

  def bottom_sensor
    all_items =
      if grouped?
        sensor_groups.flat_map { |group| group[:items] || [] }
      else
        sensor_items
      end
    all_items.find { |item| item.sensor_name == @bottom_sensor }
  end

  private

  def build_grouped_sensor_items
    build_menu_groups(group_sensors_manually)
  end

  def build_menu_groups(sensor_groups)
    groups = []
    sensor_groups.each do |group_key, sensors|
      next if sensors.none?

      items = build_menu_items_for_sensors(sensors)

      # Add virtual items for grid_power and battery_power for title display only
      items = add_virtual_title_items(items, group_key)

      groups << { name: I18n.t("balance_groups.#{group_key}"), items: }
    end
    groups
  end

  def add_virtual_title_items(items, _group_key)
    # No virtual items needed anymore, as we have individual chart classes
    items
  end

  def build_virtual_title_item(sensor_name)
    MenuItem::Component.new(
      name: Sensor::Registry[sensor_name].display_name,
      sensor_name:,
      href: nil, # No link, just for title display
      current: true,
    )
  end

  def group_sensors_manually
    # Manual grouping for power balance page
    grouped = { source: [], usage: [], finance: [], other: [] }

    available_sensors.each do |sensor_name|
      group = determine_balance_group(sensor_name)
      grouped[group] << sensor_name
    end

    # Return in desired order
    grouped
  end

  def determine_balance_group(sensor_name)
    case sensor_name
    # Source (Herkunft) - where power comes from
    when :inverter_power, :inverter_power_1, :inverter_power_2,
         :inverter_power_3, :inverter_power_4, :inverter_power_5,
         :inverter_power_difference, :inverter_power_forecast,
         :inverter_power_forecast_clearsky, :grid_import_power,
         :battery_discharging_power
      :source
      # Usage (Verwendung) - where power goes
    when :house_power,
         :house_power_without_custom,
         :wallbox_power,
         :heatpump_power,
         :grid_export_power,
         :battery_charging_power,
         /\Acustom_power_\d{2}\z/ # Custom consumers (INFLUX_SENSOR_CUSTOM_POWER_XX)
      :usage
      # Finance (Finanzen) - costs, savings, revenue
    when :grid_costs, :savings, :grid_revenue, :solar_price, :traditional_costs,
         :total_costs, :battery_savings
      :finance
      # Everything else goes to "other"
    else
      :other
    end
  end

  def build_menu_items_for_sensors(sensors)
    sensors
      .map { |sensor_name| build_menu_item(sensor_name) }
      .sort_by do |item|
        item_display_name(item.sensor_name).downcase
      end
  end

  def item_display_name(name)
    Sensor::Registry[name].display_name(:long)
  end

  def build_menu_item(sensor_name)
    MenuItem::Component.new(
      name: item_display_name(sensor_name),
      sensor_name:,
      id: item_id(sensor_name),
      href:
        url_for(
          controller: "#{helpers.controller_namespace}/home",
          sensor_name:,
          timeframe:,
        ),
      data: {
        action: 'stats-with-chart--component#loadChart dropdown--component#toggle',
        stats_with_chart__component_sensor_name_param: sensor_name,
        stats_with_chart__component_chart_url_param:
          charts_path(sensor_name:),
      },
      current: current_item?(sensor_name),
    )
  end

  def current_item?(sensor_name)
    sensor_name == @sensor_name
  end

  def selected_id
    sensor_name
  end

  def item_id(sensor_name)
    sensor_name
  end

  def charts_path(sensor_name:)
    namespace = helpers.controller_namespace

    case namespace
    when 'house'
      helpers.house_charts_path(sensor_name:, timeframe:)
    when 'heatpump'
      helpers.heatpump_charts_path(sensor_name:, timeframe:)
    when 'inverter'
      helpers.inverter_charts_path(sensor_name:, timeframe:)
    else
      helpers.balance_charts_path(sensor_name:, timeframe:)
    end
  end

  def available_sensors
    @available_sensors ||= expand_sensor_list(sensor_names)
  end

  def expand_sensor_list(sensors)
    expanded = sensors.dup

    # Replace grid_power with individual sensors
    if expanded.delete(:grid_power)
      expanded.push(:grid_import_power, :grid_export_power)
    end

    # Replace battery_power with individual sensors
    if expanded.delete(:battery_power)
      expanded.push(:battery_charging_power, :battery_discharging_power)
    end

    expanded
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
