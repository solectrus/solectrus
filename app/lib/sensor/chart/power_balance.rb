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
    sensor_names.concat(excluded_custom_sensor_names)
    sensor_names << :inverter_power_forecast if show_remaining_forecast?
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

      insert_excluded_custom_sensors(names)
      names << :inverter_power_forecast if show_remaining_forecast?
      names
    end
  end

  # Insert excluded custom sensors after house_power (mirrors balance sheet layout)
  def insert_excluded_custom_sensors(names)
    return if excluded_custom_sensor_names.empty?

    insert_pos = (names.index(:house_power) || names.index(:heatpump_power) || -1) + 1
    names.insert(insert_pos, *excluded_custom_sensor_names)
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

  # Chart.js stacked line fill (fill: '-1') needs numeric values at every
  # index. Bridge short outages with the last known value and only mark
  # longer gaps as 0 so brief sensor dropouts don't render as drops to zero.
  # The 5-minute threshold mirrors `Sensor::Chart::Base::SPAN_GAPS_MS` so
  # the inverter (sparse line) and power balance (stacked area) charts
  # treat the same outage consistently.
  #
  # Sensors excluded from house_power (custom, wallbox, heatpump, ...) are
  # filled with 0 instead of being bridged: the calculate block treats
  # their nil buckets as 0 (no subtraction from house_power), so bridging
  # them here would carry forward a value that house_power has not been
  # reduced by - making the same wattage show up both inside house_power
  # and as its own segment (issue #5517).
  def pad_nil_values!(items)
    threshold = gap_bridge_buckets
    items.each do |item|
      next if forecast_sensor?(item[:sensor_name])

      if excluded_sensor_names.include?(item[:sensor_name])
        item[:data].map! { |value| value || 0 }
      else
        bridge_short_outages!(item[:data], threshold)
      end
    end
  end

  def bridge_short_outages!(data, threshold)
    last_value = nil
    i = 0
    while i < data.size
      if data[i].nil?
        gap_end = i
        gap_end += 1 while gap_end < data.size && data[gap_end].nil?
        fill = last_value && (gap_end - i) <= threshold ? last_value : 0
        data.fill(fill, i, gap_end - i)
        i = gap_end
      else
        last_value = data[i]
        i += 1
      end
    end
  end

  GAP_BRIDGE_DURATION = 5.minutes
  private_constant :GAP_BRIDGE_DURATION

  def gap_bridge_buckets
    GAP_BRIDGE_DURATION.to_i / bucket_interval_seconds
  end

  def bucket_interval_seconds
    (interval || (timeframe.p1h? || timeframe.now? ? 30.seconds : 5.minutes)).to_i
  end

  # Sensors that appear below zero (usage/outflow)
  def consumption_sensors
    @consumption_sensors ||=
      %i[house_power heatpump_power wallbox_power battery_charging_power grid_export_power] +
      excluded_custom_sensor_names
  end

  def excluded_custom_sensor_names
    @excluded_custom_sensor_names ||=
      Sensor::Config.house_power_excluded_custom_sensors.map(&:name)
  end

  # All sensors excluded from house_power (custom + standard like wallbox/heatpump)
  def excluded_sensor_names
    @excluded_sensor_names ||=
      Sensor::Config.house_power_excluded_sensors.map(&:name)
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
    if sensor.forecast?
      return {
        tension: 0.4,
        cubicInterpolationMode: 'monotone',
        borderWidth: 0.3,
        colorClass: sensor.color_background,
        fill: true,
        noGradient: sensor.hatch_fill?,
        hatchFill: sensor.hatch_fill?,
        spanGaps: true,
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
      colorClass: sensor.color_background,
      borderRadius: (3 if type == 'bar'),
    }.compact
  end

  def interpolate?
    false
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

  # Hide forecast values before now, but seed the master-grid bucket
  # directly before now with the next future sample's value so the
  # forecast area starts max one bucket before now instead of leaving
  # a wedge until the next provider sample.
  def mask_past_forecast_values(sorted_points, data_values)
    now = Time.current
    normalized = sorted_points.map { |time_key, _| normalize_timestamp(time_key) }
    anchor_idx = normalized.rindex { |ts| ts < now }
    next_value = anchor_idx && data_values[(anchor_idx + 1)..].find { |v| v }

    data_values.map.with_index do |value, idx|
      if normalized[idx] >= now
        value
      elsif idx == anchor_idx
        next_value
      end
    end
  end
end
