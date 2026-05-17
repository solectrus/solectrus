class Sensor::Chart::Base # rubocop:disable Metrics/ClassLength
  SPAN_GAPS_MS = 15.minutes.in_milliseconds
  private_constant :SPAN_GAPS_MS

  def initialize(timeframe:, variant: nil)
    unless timeframe.is_a?(Timeframe)
      raise ArgumentError,
            "timeframe must be a Timeframe, got #{timeframe.inspect}"
    end

    @timeframe = timeframe
    @variant = variant
  end

  attr_reader :timeframe, :variant
  attr_accessor :interval

  def type
    timeframe.short? ? 'line' : 'bar'
  end

  # Override in subclasses for custom chart labels
  def label
    chart_sensors.first&.display_name
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

  def permitted?
    permitted_feature_name.nil? ||
      ApplicationPolicy.instance.feature_enabled?(permitted_feature_name)
  end

  # Override in subclasses to implement permission checks
  def permitted_feature_name
  end

  def unit
    @unit ||=
      Sensor::UnitFormatter.format(
        unit: chart_sensors.first.unit,
        context: timeframe.short? ? :rate : :total,
        scaling: :off,
      )
  end

  def crosshair_options
    return unless timeframe.short?

    {
      # Disable built-in drag-to-zoom: chartjs-plugin-zoom handles that, and
      # crosshair's doZoom crashes on null data points (data gaps).
      zoom: { enabled: false },
      # Disable cross-chart tooltip sync: we don't link charts, and it fires
      # a window-level CustomEvent on every mousemove.
      sync: { enabled: false },
    }
  end

  def options
    {
      maintainAspectRatio: false,
      plugins: {
        legend: false,
        tooltip: tooltip_options,
        zoom: zoom_options,
        crosshair: crosshair_options,
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

  # Override in subclasses to use a fixed chart color instead of the sensor's color
  def color_class(sensor)
    sensor.color_background
  end

  private

  # Aligns every dataset to the longest item's labels (1:1, plain Number
  # arrays). Sibling datasets share one timestamp grid, which lets Chart.js'
  # index-mode tooltips pair points across datasets by construction.
  def build_data
    return unless series

    items = build_chart_data_items
    master = items.max_by { |item| item[:labels]&.length || 0 }
    return unless master

    align_to_master_grid!(master[:labels], items)

    { labels: master[:labels], datasets: datasets(items) }
  end

  def series
    @series ||= build_series_data
  end

  def datasets(chart_data_items)
    chart_data_items.map do |chart_data|
      sensor = Sensor::Registry[chart_data[:sensor_name]]
      {
        id: sensor.name.to_s,
        label: sensor.display_name,
        data: chart_data[:data],
      }.merge(style_for_sensor(sensor))
    end
  end

  def align_to_master_grid!(master_labels, items)
    items.each do |item|
      item[:data] = grid_aligned_values(master_labels, item)
      item[:labels] = master_labels
    end
  end

  # Skip forecast sensors: their provider cadence is sparser than the live
  # 5-min grid by design. Linearly filling the gaps would defeat Chart.js'
  # tension/monotone smoothing -- with sparse points it draws a smooth
  # Hermite curve through the original samples instead.
  def grid_aligned_values(master_labels, item)
    values = align_values(master_labels, item[:labels], item[:data])
    return values unless type == 'line' && values.any?(&:nil?)
    return values if Sensor::Registry[item[:sensor_name]]&.forecast?

    process_gaps(master_labels, values)
  end

  def process_gaps(master_labels, values)
    values = bridge_short_gaps(master_labels, values)
    values = fill_gaps_with_zero(values) if fill_gaps_with_zero?
    values
  end

  def align_values(master_labels, item_labels, item_values)
    return item_values if item_labels == master_labels

    by_x = item_labels.zip(item_values).to_h
    master_labels.map { |x| by_x[x] }
  end

  # Linearly interpolates null runs whose time gap is within #gap_bridge_limit;
  # longer runs stay nil so Chart.js breaks line and Filler-area together.
  def bridge_short_gaps(labels, values)
    values = values.dup
    last = nil
    i = 0
    while i < values.size
      if values[i].nil?
        stop = i
        stop += 1 while stop < values.size && values[stop].nil?
        interpolate_gap!(labels, values, i, stop, last) if last && stop < values.size
        i = stop
      else
        last = i
        i += 1
      end
    end
    values
  end

  def interpolate_gap!(labels, values, start, stop, last)
    span = (labels[stop] - labels[last]).to_f
    return if span > gap_bridge_limit

    a = values[last]
    delta = values[stop] - a
    (start...stop).each do |j|
      values[j] = a + (delta * (labels[j] - labels[last]) / span)
    end
  end

  # Collapses every nil left after bridge_short_gaps to 0, for consumers where
  # "no measurement" means 0 W (#fill_gaps_with_zero?). bridge_short_gaps has
  # already interpolated the short, bridgeable gaps -- a slow write cadence
  # (issue #5567); what remains is long idle phases and the window edges,
  # which render as a flat 0 baseline instead of a line break.
  def fill_gaps_with_zero(values)
    values.map { |value| value || 0 }
  end

  def style
    style_for_sensor(sensor)
  end

  def style_for_sensor(sensor)
    {
      fill: true,
      tension: 0.4,
      cubicInterpolationMode: 'monotone',
      borderWidth: 1,
      pointRadius: 0,
      pointHoverRadius: 5,
      colorClass: color_class(sensor),
      colorScale: (sensor.color_scale if sensor.respond_to?(:color_scale)),
      hatchFill: sensor.hatch_fill?,
      noGradient: type == 'bar' || sensor.hatch_fill?,
      borderRadius: (3 if type == 'bar'),
      borderSkipped: (bar_border_skip if type == 'bar'),
      spanGaps: (gap_bridge_limit if type == 'line'),
    }.compact
  end

  # Override in subclasses (e.g. MinmaxBase) to customize border rounding
  def bar_border_skip
    'start'
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
    return {} unless type == 'line'

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

    if timeframe.now?
      # Pin the x-axis to a fixed 1-hour window ending at the current time
      # (matches the P1H InfluxDB query below). Without this, Chart.js would
      # auto-fit the axis to the last data point, hiding any trailing gap
      # when the most recent measurement is older than "now".
      now = Time.current
      options[:min] = (now - 1.hour).to_i * 1000
      options[:max] = now.to_i * 1000
    else
      options[:min] = timeframe.beginning.to_i * 1000
      options[:max] = timeframe.ending.to_i * 1000
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
    time_unit_config('hour', format, format)
  end

  def day_config(display_format, tooltip_format)
    time_unit_config('day', display_format, tooltip_format, round: 'day')
  end

  def month_config(display_format, tooltip_format)
    time_unit_config('month', display_format, tooltip_format, round: 'month')
  end

  def year_config(display_format, tooltip_format)
    time_unit_config('year', display_format, tooltip_format, round: 'year')
  end

  def time_unit_config(unit, display_format, tooltip_format, round: nil)
    {
      unit:,
      displayFormats: {
        unit.to_sym => display_format,
      },
      tooltipFormat: tooltip_format,
      round:,
    }.compact
  end

  def day_display_format
    case timeframe.relative_count.to_i
    when ..8
      'ccc' # Sun, Mon, Tue
    when 9..31
      'd' # 1, 2, 3
    when 32..280
      'd. LLL' # 1. Jan, 2. Feb
    else
      'LLL yyyy' # Jan 2024, Feb 2024
    end
  end

  def range_display_format
    case timeframe.days_passed
    when ..180
      'd. LLL' # 1. Jan, 2. Feb
    else
      'LLL yyyy' # Jan 2024, Feb 2024
    end
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

  def build_chart_data_item(sensor_name)
    # Return empty dataset for sensors without data (e.g., inverter_power for future days)
    return empty_dataset(sensor_name) unless series.respond_to?(sensor_name)

    # Get the correct aggregations for this sensor
    aggregations = aggregations_for_sensor(sensor_name)
    points_hash = series.public_send(sensor_name, *aggregations)

    # Return empty dataset if no data available
    return empty_dataset(sensor_name) unless points_hash

    # Sort by timestamp to ensure chronological order
    sorted_points = points_hash.sort_by { |time_key, _| time_key }

    # Filter out future data points (except for forecast sensors)
    sorted_points = filter_future_points(sorted_points, sensor_name)

    {
      sensor_name:,
      labels: sorted_points.map { |time_key, _| timestamp_to_ms(time_key) },
      data: transform_data(sorted_points.map(&:second), sensor_name),
    }
  end

  def empty_dataset(sensor_name)
    { sensor_name:, labels: [], data: [] }
  end

  # Transform data for specific sensor (can be overridden for sign changes etc.)
  def transform_data(data, sensor_name)
    # Apply value range validation to ensure physically valid values
    apply_value_range_validation(data, sensor_name)
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
    Sensor::Query::Total
      .new(timeframe) do |q|
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

        q.group_by sql_grouping_period
      end
      .call
  end

  # Build InfluxDB-based series data
  def build_influx_series
    Sensor::Query::Series.new(
      chart_sensor_names,
      timeframe.now? ? Timeframe.new('P1H') : timeframe,
      interval:,
    ).call(
      interpolate: interpolate?,
      fill_previous: fill_missing_with_previous?,
    )
  end

  # Override this in subclasses to enable interpolation
  def interpolate?
    false
  end

  # Override in subclasses whose sensors read 0 W while idle. Every nil left
  # after the bridge_short_gaps pass (a gap longer than #gap_bridge_limit or
  # a window edge) is set to 0, so an idle consumer renders as a flat 0
  # baseline instead of a line break.
  def fill_gaps_with_zero?
    false
  end

  # Longest null gap (in ms) that is bridged: server-side bridge_short_gaps
  # interpolates across it, and Chart.js spanGaps connects the line across a
  # gap of that length (relevant for client-appended live "now" updates).
  # Override in subclasses to narrow it to the cadence-jitter scale, or
  # return 0 to disable bridging entirely.
  def gap_bridge_limit
    SPAN_GAPS_MS
  end

  # Override in subclasses for sparse, low-frequency sensors whose value
  # persists between samples (e.g. battery SOC). Empty aggregation buckets
  # are forward-filled with the most recent known value so the chart spans
  # the full window without gaps on the leading/trailing edges.
  def fill_missing_with_previous?
    false
  end

  # Apply sensor value range validation to chart data
  def apply_value_range_validation(data, sensor_name)
    return data unless data.is_a?(Array)

    sensor = Sensor::Registry[sensor_name]
    data.map { |value| sensor.clamp_value(value) }
  end

  # Trim live (non-forecast) data points beyond Time.current. Aggregation
  # buckets can extend slightly past now (the bucket containing the current
  # instant is stamped at its right edge, which is in the future), and the
  # forecast chart spans timeframes where no #today? guard would catch it.
  def filter_future_points(sorted_points, sensor_name)
    return sorted_points if Sensor::Registry[sensor_name].forecast?

    now = Time.current
    sorted_points.take_while do |time_key, _|
      normalize_timestamp(time_key) <= now
    end
  end

  # Convert timestamp to milliseconds for Chart.js
  def timestamp_to_ms(time_key)
    normalize_timestamp(time_key).to_i * 1000
  end

  # Convert time_key to Time object
  def normalize_timestamp(time_key)
    time_key.is_a?(Time) ? time_key : time_key.to_time
  end
end
