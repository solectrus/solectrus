class ChartSelector::Component < ViewComponent::Base # rubocop:disable Metrics/ClassLength
  def initialize(
    sensor_name:,
    timeframe:,
    sensor_names:,
    menu_config: {},
    top_sensor: nil,
    bottom_sensor: nil
  )
    super()
    raise ArgumentError unless sensor_name.is_a?(Symbol)
    raise ArgumentError unless sensor_names.all?(Symbol)

    @sensor_name = sensor_name
    @timeframe = timeframe
    @sensor_names = sensor_names
    @menu_config = menu_config || {}
    @top_sensor = top_sensor
    @bottom_sensor = bottom_sensor
  end
  attr_reader :sensor_name, :timeframe, :sensor_names, :menu_config

  def display_name
    override = menu_config.dig(:display_names, sensor_name)
    return override if override

    own = Sensor::Registry[sensor_name].display_name
    partner = combined_partner
    return own unless partner

    # A combined chart is offered as each of its halves, so the half names the
    # other one and the user sees which two the chart draws.
    "#{own} (& #{Sensor::Registry[partner].display_name})"
  end

  # The button stands over the chart. Where the chart shares the row with the
  # stats its half is narrow, so the menu hangs from the right edge rather than
  # running past the card. A chart that has the row to itself has the room, and
  # a menu under its own button reads better there.
  def menu_position
    helpers.year_comparison? ? :center_always : :center
  end

  def sensor_groups
    @sensor_groups ||= build_grouped_sensor_items
  end

  def grouped?
    return false if menu_config[:grouped] == false

    sensor_groups.length > 1
  end

  def sensor_items
    return [] if sensor_groups.empty?

    if grouped?
      sensor_groups.first&.dig(:items) || []
    else
      all_items
    end
  end

  def top_sensor
    all_items.find { |item| item.sensor_name == @top_sensor }
  end

  def bottom_sensor
    all_items.find { |item| item.sensor_name == @bottom_sensor }
  end

  private

  # The other half of the combined chart this sensor is offered as, if it is
  # offered as a half at all (see the `chart entries:` DSL).
  def combined_partner
    owner = Sensor::Config.chart_sensor_by_name[sensor_name]
    return if owner.nil? || owner.name == sensor_name

    owner.chart_partner_names(sensor_name).first
  end

  def all_items
    @all_items ||= sensor_groups.flat_map { |group| group[:items] || [] }
  end

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
         :total_consumption,
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
        [menu_item_order(item.sensor_name), item_display_name(item.sensor_name).downcase]
      end
  end

  def item_display_name(name)
    menu_config.dig(:display_names, name) || Sensor::Registry[name].display_name(:long)
  end

  def build_menu_item(sensor_name)
    compare = compare_for(sensor_name)

    MenuItem::Component.new(
      name: item_display_name(sensor_name),
      sensor_name:,
      id: item_id(sensor_name),
      separator_before: menu_item_separator_before?(sensor_name),
      href: path_for('home', sensor_name:, compare:),
      data: item_data(sensor_name, compare),
      current: current_item?(sensor_name),
    )
  end

  # Whether this sensor stays in the year comparison, and in which of them. One
  # that has no value of its own cannot be compared, so picking it leaves the
  # comparison behind.
  def compare_for(sensor_name)
    return unless helpers.year_comparison?
    return unless Sensor::Chart::YearComparison.available_for?(
      Sensor::Registry[sensor_name],
    )

    helpers.year_comparison
  end

  # Normally a pick swaps the chart frame alone, which is why the item carries
  # the URL of that frame. Leaving the comparison changes the layout of the
  # page instead: the stats come back beside the chart, and only a full load
  # brings them. Such an item drops the frame swap and navigates.
  def item_data(sensor_name, compare)
    if helpers.year_comparison? && compare.nil?
      return { action: 'dropdown--component#toggle' }
    end

    {
      action:
        'stats-with-chart--component#loadChart dropdown--component#toggle',
      stats_with_chart__component_sensor_name_param: sensor_name,
      stats_with_chart__component_chart_url_param:
        path_for('charts', sensor_name:, compare:),
    }
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

  def path_for(kind, sensor_name:, compare:)
    url_for(
      controller: "#{helpers.controller_namespace}/#{kind}",
      sensor_name:,
      timeframe:,
      compare:,
    )
  end

  # A combined chart gets one entry per half, so the menu shows two items
  # where the page lists one sensor.
  def available_sensors
    @available_sensors ||=
      sensor_names.flat_map { |name| Sensor::Registry[name].chart_entry_names }
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

  def menu_order
    menu_config.fetch(:order, {})
  end

  def menu_items
    @menu_items ||= Array(menu_config[:items])
  end

  def menu_item_order(sensor_name)
    if menu_items.any?
      index = menu_items.index(sensor_name)
      return index if index
    end

    menu_order.fetch(sensor_name, 999)
  end

  def menu_item_separator_before?(sensor_name)
    if menu_items.any?
      index = menu_items.index(sensor_name)
      return false unless index&.positive?

      return menu_items[index - 1] == :_
    end

    Array(menu_config[:separator_before]).include?(sensor_name)
  end
end
