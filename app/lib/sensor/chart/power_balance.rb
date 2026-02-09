class Sensor::Chart::PowerBalance < Sensor::Chart::Base # rubocop:disable Metrics/ClassLength
  # Sensors to load from database (some are optional)
  DATA_SENSOR_NAMES = %i[
    inverter_power
    grid_import_power
    grid_export_power
    battery_discharging_power
    battery_charging_power
    house_power
    heatpump_power
    wallbox_power
  ].freeze

  # Sensors to display
  # Order matters for stacking and should mirror the balance sheet:
  # - source stack (positive, above zero): inverter, battery_discharging, grid_import
  # - usage stack (negative, below zero): house, heatpump, wallbox, battery_charging, grid_export
  DISPLAY_SENSOR_NAMES = %i[
    inverter_power
    battery_discharging_power
    grid_import_power
    house_power
    heatpump_power
    wallbox_power
    battery_charging_power
    grid_export_power
  ].freeze

  public_constant :DATA_SENSOR_NAMES, :DISPLAY_SENSOR_NAMES

  def label
    I18n.t('charts.balance')
  end

  # Place this chart in the "Other" menu group
  def menu_group
    :other
  end

  def permitted_feature_name
    :power_balance_chart
  end

  def options
    super.deep_merge(
      plugins: {
        legend: legend_options,
        tooltip: {
          displayColors: true,
        },
      },
      scales: {
        x: {
          stacked: true,
        },
        y: {
          stacked: true,
          ticks: {
            callback: 'formatAbs',
          },
        },
      },
    )
  end

  private

  def chart_sensor_names
    sensor_names = DATA_SENSOR_NAMES.select { |name| Sensor::Config.exists?(name) }
    if show_remaining_forecast?
      sensor_names << :inverter_power_forecast
    end
    sensor_names
  end

  def chart_sensors
    @chart_sensors ||= display_sensor_names.map { |name| Sensor::Registry[name] }
  end

  # Filter display sensors to only include configured ones
  def display_sensor_names
    @display_sensor_names ||= begin
      names =
        DISPLAY_SENSOR_NAMES.select do |name|
          Sensor::Config.exists?(name)
        end
      names << :inverter_power_forecast if show_remaining_forecast?
      names
    end
  end

  def build_chart_data_items
    items =
      display_sensor_names.map do |name|
        data = build_chart_data_item(name)
        # Negate consumption stack (below zero)
        consumption_sensors.include?(name) ? negate_values(data) : data
      end

    items.reject! { |item| item[:data].compact.blank? }

    # Keep a list of sensors that actually have data in this timeframe.
    @display_sensor_names_with_data = items.pluck(:sensor_name)

    # For stacked line charts, replace nil with 0 so that fill: '-1'
    # works correctly even when the target dataset has sparse data.
    # Physically correct: no measurement = no power = 0 W.
    pad_nil_values!(items) if type == 'line'

    items
  end

  # Replace nil with 0 in data arrays (skip forecast datasets)
  def pad_nil_values!(items)
    items.each do |item|
      next if forecast_sensor?(item[:sensor_name])

      item[:data].map! { |v| v || 0 }
    end
  end

  # Sensors that appear below zero (usage/outflow)
  def consumption_sensors
    %i[house_power heatpump_power wallbox_power battery_charging_power grid_export_power]
  end

  # Negate values for display below zero line
  def negate_values(chart_data)
    return chart_data if chart_data[:data].blank?

    chart_data.merge(
      data: chart_data[:data].map { |v| v ? -v : nil },
    )
  end

  def build_chart_data_item(sensor_name)
    return super unless forecast_sensor?(sensor_name)

    build_remaining_forecast_data_item(sensor_name)
  end

  def datasets(chart_data_items)
    chart_data_items.map do |chart_data|
      sensor = Sensor::Registry[chart_data[:sensor_name]]
      {
        id: sensor.name.to_s,
        label: sensor.display_name,
        data: chart_data[:data],
      }.merge(style_for_dataset(sensor, 0))
    end
  end

  def legend_options
    {
      display: true,
      position: 'top',
      labels: {
        usePointStyle: true,
        pointStyle: 'circle',
        boxWidth: 8,
        boxHeight: 8,
        padding: 15,
      },
    }
  end

  def style_for_dataset(sensor, _index)
    if sensor.category == :forecast
      return {
        tension: 0.4,
        cubicInterpolationMode: 'monotone',
        borderWidth: 0.3,
        colorClass: sensor.color_chart,
        fill: true,
        noGradient: sensor.hatch_fill?,
        hatchFill: sensor.hatch_fill?,
      }
    end

    base = style_for_sensor(sensor)
    stack =
      if type == 'bar'
        'combined'
      else
        consumption_sensors.include?(sensor.name) ? 'usage' : 'source'
      end
    position = stack_position(sensor.name, stack)
    fill = if type == 'line'
      position.zero? ? 'origin' : '-1'
    else
      true
    end

    base.merge(
      fill:,
      stack:,
      noGradient: true,
      colorClass: sensor.color_background,
    )
  end

  # Get position of sensor within its stack (for fill calculation)
  def stack_position(sensor_name, stack)
    sensors_in_stack = display_sensor_names_for_stack.select do |name|
      expected_stack = consumption_sensors.include?(name) ? 'usage' : 'source'
      expected_stack == stack
    end
    sensors_in_stack.index(sensor_name) || 0
  end

  def display_sensor_names_for_stack
    @display_sensor_names_with_data || display_sensor_names
  end

  def style_for_sensor(sensor)
    {
      tension: 0.4,
      cubicInterpolationMode: 'monotone',
      borderWidth: 1,
      pointRadius: 0,
      pointHoverRadius: 5,
      colorClass: sensor.color_chart,
      borderRadius: (3 if type == 'bar'),
    }.compact
  end

  def interpolate?
    timeframe.short?
  end

  def show_remaining_forecast?
    timeframe.today? && Sensor::Config.exists?(:inverter_power_forecast)
  end

  def forecast_sensor?(sensor_name)
    sensor_name == :inverter_power_forecast && show_remaining_forecast?
  end

  def build_remaining_forecast_data_item(sensor_name)
    return empty_dataset(sensor_name) unless series.respond_to?(sensor_name)

    aggregations = aggregations_for_sensor(sensor_name)
    points_hash = series.public_send(sensor_name, *aggregations)
    return empty_dataset(sensor_name) unless points_hash

    sorted_points = points_hash.sort_by { |time_key, _| time_key }
    labels = sorted_points.map { |time_key, _| timestamp_to_ms(time_key) }
    data_values = transform_data(sorted_points.map(&:second), sensor_name)

    {
      sensor_name:,
      labels:,
      data: mask_past_forecast_values(sorted_points, data_values),
    }
  end

  def mask_past_forecast_values(sorted_points, data_values)
    now = Time.current
    masked_values = sorted_points.zip(data_values)
    masked_values.map! do |(time_key, _), value|
      normalize_timestamp(time_key) >= now ? value : nil
    end
    masked_values
  end
end
