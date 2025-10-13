class Sensor::Chart::Base # rubocop:disable Metrics/ClassLength
  def initialize(timeframe:, variant: nil)
    unless timeframe.is_a?(Timeframe)
      raise ArgumentError,
            "timeframe must be a Timeframe, got #{timeframe.inspect}"
    end

    @timeframe = timeframe
    @variant = variant
  end

  attr_reader :timeframe, :variant

  def type
    timeframe.short? ? 'line' : 'bar'
  end

  def data
    @data ||= build_data
  end

  def blank?
    datasets = data&.dig(:datasets)
    return true if datasets.blank?

    datasets.none? do |dataset|
      Array(dataset[:data]).compact.any? do |value|
        Array(value).compact.present?
      end
    end
  end

  def unit
    @unit ||=
      Sensor::UnitFormatter.format(
        unit: chart_sensors.first.unit,
        context: timeframe.short? ? :power : :energy,
        scaling: :off,
      )
  end

  def options
    {
      maintainAspectRatio: false,
      plugins: {
        legend: false,
        tooltip: tooltip_options,
        zoom: zoom_options,
        crosshair: timeframe.short?,
      },
      animation: {
        easing: 'easeOutQuad',
        duration: 300,
      },
      interaction: {
        intersect: !timeframe.short?,
        mode: 'index',
      },
      elements: {
        point: {
          radius: 0,
          hitRadius: 5,
          hoverRadius: 5,
        },
      },
      scales: {
        x: x_scale_options,
        y: y_scale_options,
      },
    }
  end

  def suggested_min
    0
  end

  def suggested_max
    case chart_sensors.first.unit
    when :percent
      100
    when :watt
      # This ensures that very small values does not fill up the chart
      50
    end
  end

  private

  def build_data
    return unless series

    chart_data_items = build_chart_data_items

    # Use the chart item with the most data points for labels
    chart_item_with_most_data =
      chart_data_items.max_by { |item| item[:data]&.length || 0 }

    {
      labels: labels(chart_item_with_most_data),
      datasets: datasets(chart_data_items),
    }
  end

  def series
    @series ||= build_series_data
  end

  def labels(chart_data)
    chart_data[:labels]
  end

  def datasets(chart_data_items)
    chart_data_items.map do |chart_data|
      sensor_name = chart_data[:sensor_name]
      sensor = Sensor::Registry[sensor_name]
      {
        id: sensor.name.to_s,
        label: sensor.display_name,
        data: chart_data[:data],
      }.merge(style_for_sensor(sensor))
    end
  end

  def style
    style_for_sensor(sensor)
  end

  def style_for_sensor(sensor)
    {
      fill: true,
      tension: 0.4,
      borderWidth: 1,
      pointRadius: 0,
      pointHoverRadius: 5,
      backgroundColor: sensor.color_hex,
      borderColor: sensor.color_hex,
      borderRadius: (3 if type == 'bar'),
    }.compact
  end

  def tooltip_options
    {
      backgroundColor: 'rgba(255, 255, 255, 1.0)',
      titleColor: '#222',
      bodyColor: '#222',
      footerColor: '#222',
      borderColor: 'rgba(0, 8, 16, 0.6)',
      borderWidth: 1,
      displayColors: false,
      titleFont: {
        size: 15,
      },
      bodyFont: {
        size: 18,
      },
      caretPadding: 15,
      caretSize: 10,
    }
  end

  def zoom_options
    return {} unless timeframe.short?

    { zoom: { drag: { enabled: true }, mode: 'x' } }
  end

  def x_scale_options
    options = {
      stacked: true,
      grid: {
        drawOnChartArea: false,
      },
      type: 'time',
      adapters: {
        date: {
          zone: Time.zone.name,
        },
      },
      ticks: x_tick_options,
      time: x_time_options,
    }

    # Extend x-axis to start of day for day charts
    if should_extend_x_axis_to_start_of_day?
      options[:min] = timeframe.date.beginning_of_day.to_i * 1000
    end

    # Extend x-axis to end of day for current day charts
    if should_extend_x_axis_to_end_of_day?
      options[:max] = timeframe.date.end_of_day.to_i * 1000
    end

    options
  end

  def y_scale_options
    {
      suggestedMax: suggested_max,
      suggestedMin: suggested_min,
      ticks: {
        beginAtZero: true,
        maxTicksLimit: 10,
      },
    }
  end

  def x_tick_options
    tick_configs[timeframe.id] || { maxRotation: 0 }
  end

  def x_time_options
    time_format_configs[timeframe.id] || {}
  end

  def tick_configs
    @tick_configs ||= {
      now: tick_config(15),
      hours: tick_config(3),
      day: tick_config(3),
      days: tick_config(timeframe.relative_count.to_i > 14 ? 2 : 1),
      range: tick_config(timeframe.relative_count.to_i > 14 ? 2 : 1),
      week: tick_config(1),
      month: tick_config(2),
      months: tick_config(1),
      year: tick_config(1),
      years: tick_config(1),
      all: tick_config(1),
    }
  end

  def tick_config(step_size)
    { stepSize: step_size, maxRotation: 0 }
  end

  def time_format_configs
    @time_format_configs ||= {
      now: {
        unit: 'minute',
        displayFormats: {
          minute: 'HH:mm',
        },
        tooltipFormat: 'HH:mm:ss',
      },
      hours: hour_config('HH:mm'),
      day: hour_config('HH:mm'),
      days: day_config(day_display_format, 'cccc, dd.MM.yyyy'),
      range: day_config(range_display_format, 'cccc, dd.MM.yyyy'),
      week: day_config('ccc', 'cccc, dd.MM.yyyy'),
      month: day_config('d', 'cccc, dd.MM.yyyy'),
      months: month_config('LLL', 'MMMM yyyy'),
      year: month_config('LLL', 'MMMM yyyy'),
      years: year_config('yyyy', 'yyyy'),
      all: year_config('yyyy', 'yyyy'),
    }
  end

  def hour_config(format)
    { unit: 'hour', displayFormats: { hour: format }, tooltipFormat: format }
  end

  def day_config(display_format, tooltip_format)
    {
      unit: 'day',
      displayFormats: {
        day: display_format,
      },
      tooltipFormat: tooltip_format,
      round: 'day',
    }
  end

  def month_config(display_format, tooltip_format)
    {
      unit: 'month',
      displayFormats: {
        month: display_format,
      },
      tooltipFormat: tooltip_format,
      round: 'month',
    }
  end

  def year_config(display_format, tooltip_format)
    {
      unit: 'year',
      displayFormats: {
        year: display_format,
      },
      tooltipFormat: tooltip_format,
      round: 'year',
    }
  end

  def day_display_format
    case timeframe.relative_count.to_i
    when ..8
      'ccc'
    when 9..31
      'd'
    when 32..280
      'd. LLL'
    else
      'LLL yyyy'
    end
  end

  def range_display_format
    timeframe.relative_count.to_i < 8 ? 'ccc' : 'd'
  end

  # Template methods that can be overridden for custom behavior

  # Returns array of sensor names to fetch data for - MUST be implemented by subclasses
  def chart_sensor_names
    # :nocov:
    raise NotImplementedError, 'Subclasses must implement chart_sensor_names'
    # :nocov:
  end

  # Returns array of sensor definitions used for datasets
  def chart_sensors
    @chart_sensors ||= chart_sensor_names.map { |name| Sensor::Registry[name] }
  end

  # Builds chart data items from series data
  def build_chart_data_items
    chart_sensor_names.map { |sensor_name| build_chart_data_item(sensor_name) }
  end

  # Transform data for specific sensor (can be overridden for sign changes etc.)
  def transform_data(data, sensor_name)
    # Apply value range validation to ensure physically valid values
    apply_value_range_validation(data, sensor_name)
  end

  def build_chart_data_item(sensor_name)
    # Return empty dataset for sensors without data (e.g., inverter_power for future days)
    unless series.respond_to?(sensor_name)
      return { sensor_name:, labels: [], data: [] }
    end

    # Get the correct aggregations for this sensor
    aggregations = aggregations_for_sensor(sensor_name)
    points_hash = series.public_send(sensor_name, *aggregations)

    # Return empty dataset if no data available
    return { sensor_name:, labels: [], data: [] } if points_hash.nil?

    # Sort by timestamp to ensure chronological order
    sorted_points = points_hash.sort_by { |time_key, _| time_key }

    # Filter out future data points for current day (except for forecast sensors)
    sorted_points = filter_future_points(sorted_points, sensor_name)

    labels =
      sorted_points.map do |time_key, _|
        timestamp = time_key.is_a?(Time) ? time_key : time_key.to_time

        timestamp.to_i * 1000 # Convert to milliseconds for Chart.js
      end

    data = transform_data(sorted_points.map(&:second), sensor_name)

    { sensor_name:, labels:, data: }
  end

  def unit_string
    case sensor.unit
    when :celsius
      '°C'
    when :percent
      '%'
    else
      timeframe.short? ? 'W' : 'Wh'
    end
  end

  # Template methods that can be overridden by specific chart classes

  # Build series data - override this method for custom data loading
  def build_series_data
    use_sql_for_timeframe? ? build_sql_series : build_influx_series
  end

  # Determine if SQL should be used for this timeframe
  def use_sql_for_timeframe?
    return false if timeframe.now? || timeframe.hours?
    return false if timeframe.day? # Single day can still use InfluxDB

    # Use SQL for multiple days, weeks, months, years
    true
  end

  # Get aggregations for a specific sensor (meta_agg, base_agg)
  def aggregations_for_sensor(sensor_name)
    if use_sql_for_timeframe?
      sql_aggregations_for_sensor(sensor_name)
    else
      influx_aggregations_for_sensor(sensor_name)
    end
  end

  # SQL aggregations - override in specific classes for custom logic
  def sql_aggregations_for_sensor(sensor_name)
    sensor_def = Sensor::Registry[sensor_name]
    base_agg = preferred_aggregation_for_sensor(sensor_def)
    meta_agg = meta_aggregation_for_timeframe(sensor_def)
    [meta_agg, base_agg]
  end

  # Determine meta aggregation based on timeframe and sensor type
  def meta_aggregation_for_timeframe(sensor_def)
    preferred_meta_agg =
      case timeframe.id
      when :year, :years, :all, :months
        # For yearly and multi-month charts, we want totals (sums) for each period
        :sum
      else
        # For shorter timeframes, only temperature and percentage sensors should be averaged
        # All other units (watt, gram, euro, etc.) should be summed
        %i[celsius percent].include?(sensor_def.unit) ? :avg : :sum
      end

    # Ensure the sensor actually supports this meta aggregation
    supported_meta_aggs = sensor_def.summary_meta_aggregations
    if supported_meta_aggs.include?(preferred_meta_agg)
      preferred_meta_agg
    else
      # Fallback to the first supported meta aggregation
      supported_meta_aggs.first
    end
  end

  # InfluxDB aggregations - can be overridden
  def influx_aggregations_for_sensor(_sensor_name)
    %i[avg avg] # Default for InfluxDB series data
  end

  # Determine preferred aggregation for sensor type
  def preferred_aggregation_for_sensor(sensor_def)
    aggregations = sensor_def.allowed_aggregations

    # Prefer sum for power sensors (shows energy over time period)
    return :sum if aggregations.include?(:sum) && sensor_def.unit == :watt

    # For temperature sensors, prefer average
    return :avg if aggregations.include?(:avg) && sensor_def.unit == :celsius

    # For percentage sensors (SOC, autarky), prefer average
    return :avg if aggregations.include?(:avg) && sensor_def.unit == :percent

    # Default: use the first available aggregation
    aggregations.first
  end

  # SQL grouping period - can be overridden
  def sql_grouping_period
    case timeframe.id
    when :all, :years
      :year
    when :year, :months
      :month
    else
      :day
    end
  end

  # Build SQL-based series data
  def build_sql_series
    Sensor::Query::Sql
      .new do |q|
        chart_sensor_names.each do |name|
          meta_agg, base_agg = sql_aggregations_for_sensor(name)
          case meta_agg
          when :sum
            q.sum name, base_agg
          when :avg
            q.avg name, base_agg
          when :min
            q.min name, base_agg
          when :max
            q.max name, base_agg
          end
        end

        q.timeframe timeframe
        q.group_by sql_grouping_period
      end
      .call
  end

  # Build InfluxDB-based series data
  def build_influx_series
    Sensor::Query::Influx::Series.new(
      chart_sensor_names,
      timeframe.now? ? Timeframe.new('P1H') : timeframe,
    ).call(interpolate: interpolate?)
  end

  # Override this in subclasses to enable interpolation
  def interpolate?
    false
  end

  # Determine if we should extend the x-axis to start of day
  def should_extend_x_axis_to_start_of_day?
    # Extend for all day timeframes to ensure x-axis always starts at 00:00
    timeframe.day?
  end

  # Determine if we should extend the x-axis to end of day
  def should_extend_x_axis_to_end_of_day?
    # Only extend for day timeframes showing today's data
    return false unless timeframe.day?

    # Check if this is today's data (not a historical day)
    timeframe.date == Date.current
  end

  # Apply sensor value range validation to chart data
  def apply_value_range_validation(data, sensor_name)
    return data unless data.is_a?(Array)

    sensor = Sensor::Registry[sensor_name]
    data.map { |value| sensor.clamp_value(value) }
  end

  # Filter out future data points for current day charts (except for forecast sensors)
  def filter_future_points(sorted_points, sensor_name)
    # Skip filtering if not today or if sensor is a forecast
    return sorted_points unless timeframe.today?
    return sorted_points if Sensor::Registry[sensor_name].category == :forecast

    # Filter out points in the future (use take_while since points are sorted)
    now = Time.current
    sorted_points.take_while do |time_key, _|
      timestamp = time_key.is_a?(Time) ? time_key : time_key.to_time
      timestamp <= now
    end
  end
end
