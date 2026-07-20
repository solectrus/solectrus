class Sensor::Chart::Base # rubocop:disable Metrics/ClassLength
  # Floor for #gap_bridge_limit and the client-side Chart.js spanGaps. The
  # actual server-side bridging widens automatically for sparse sensors
  # (#effective_gap_bridge_limit), so this floor only sets how long a gap
  # in a *dense* sensor may be before it stays a visible break. 5 minutes
  # covers a single missed bucket at the typical 5-min cadence (and any
  # cadence-jitter for faster sensors) without hiding real outages.
  SPAN_GAPS_MS = 5.minutes.in_milliseconds
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
      layout: layout_options,
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
    }.compact
  end

  # Radius of the hover dot that doubles as the live flash, highlighted by
  # stats_with_chart (see #style_for_sensor).
  POINT_HOVER_RADIUS = 5
  private_constant :POINT_HOVER_RADIUS

  # On the live "now" chart the newest point sits right at the right edge.
  # Reserve the dot radius plus a 1px buffer so the flash dot can overflow the
  # plot area instead of being clipped, paired with the dataset `clip` in
  # #style_for_sensor.
  FLASH_DOT_HEADROOM = POINT_HOVER_RADIUS + 1
  private_constant :FLASH_DOT_HEADROOM

  def layout_options
    { padding: { right: FLASH_DOT_HEADROOM } } if timeframe.now?
  end

  # Standard legend for stacked charts that show several named segments.
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
    labels = drop_leading_lookback(master[:labels], items)

    { labels:, datasets: datasets(items) }
  end

  # Forward-fill seeding (#series_lookback) fetches buckets before the window
  # start; they exist only to carry a value into the leading edge and are
  # clipped from view. Drop them once the fill has run, so the payload holds
  # exactly the requested window instead of the extended range.
  def drop_leading_lookback(labels, items)
    return labels unless series_lookback.positive? && labels.present?

    cutoff = labels.first + series_lookback.in_milliseconds
    drop = labels.index { |label| label >= cutoff } || 0
    return labels if drop.zero?

    items.each { |item| item[:data] = item[:data].drop(drop) }
    labels.drop(drop)
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
        spanGaps: chart_data[:span_gaps_ms],
      }.compact.merge(style_for_sensor(sensor))
    end
  end

  def align_to_master_grid!(master_labels, items)
    items.each do |item|
      item[:data] = grid_aligned_values(master_labels, item)
      item[:labels] = master_labels
      item[:span_gaps_ms] = compute_span_gaps_ms(master_labels, item[:data])
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

    process_gaps(master_labels, values, item[:sensor_name])
  end

  def process_gaps(master_labels, values, sensor_name)
    if bridge_gaps?(sensor_name)
      values = bridge_short_gaps(master_labels, values)
      values = fill_trailing_edge(master_labels, values) if sparse? && timeframe.now?
    end
    values = fill_gaps_with_zero(values) if fill_gaps_with_zero?
    values
  end

  # Override in subclasses where bridging is valid for some sensors but not
  # for others. A sensor that answers false keeps its nil buckets untouched,
  # so #fill_gaps_with_zero? (if set) collapses them to 0 -- for sensors whose
  # nil genuinely means "no power", not "no measurement".
  def bridge_gaps?(_sensor_name)
    true
  end

  # On the live view a sparse sensor's newest sample can sit a few minutes
  # before the window edge, leaving trailing nulls between it and the point the
  # live updater appends at "now" -- a visible gap. Carry the last value
  # forward to the edge so the historical line meets the live tail. Capped at
  # #gap_bridge_limit, so a collector that fell silent long ago still ends in a
  # gap rather than a value dragged to "now".
  def fill_trailing_edge(labels, values)
    last = values.rindex { |value| !value.nil? }
    return values unless last

    values = values.dup
    ((last + 1)...values.size).each do |j|
      break if labels[j] - labels[last] > gap_bridge_limit

      values[j] = values[last]
    end
    values
  end

  def align_values(master_labels, item_labels, item_values)
    return item_values if item_labels == master_labels

    by_x = item_labels.zip(item_values).to_h
    master_labels.map { |x| by_x[x] }
  end

  # Linearly interpolates null runs whose time gap is within the effective
  # bridge limit (see #effective_gap_bridge_limit); longer runs stay nil so
  # Chart.js breaks line and Filler-area together.
  def bridge_short_gaps(labels, values)
    limit = effective_gap_bridge_limit(labels, values)
    values = values.dup
    last = nil
    i = 0
    while i < values.size
      if values[i].nil?
        stop = i
        stop += 1 while stop < values.size && values[stop].nil?
        interpolate_gap!(labels, values, i, stop, last, limit) if last && stop < values.size
        i = stop
      else
        last = i
        i += 1
      end
    end
    values
  end

  # Adapts the bridge limit to the sensor's actual sample cadence: detects
  # the median spacing between non-null samples and bridges up to 2x that
  # cadence (one missed sample at the detected cadence). Never shrinks
  # below #gap_bridge_limit -- this only EXPANDS the default for sparse
  # sensors (slow polling, artificial backfills) without weakening it for
  # densely polled ones. An explicit base of 0 stays 0: disable wins.
  def effective_gap_bridge_limit(labels, values)
    base = gap_bridge_limit
    return base unless base.positive?

    cadence = detected_cadence_ms(labels, values)
    cadence && cadence * 2 > base ? cadence * 2 : base
  end

  # Need at least 3 samples (2 spacings) -- with a single spacing the
  # "cadence" is just the gap itself, which would always bridge across it
  # regardless of how long the outage really is.
  #
  # The median (not the minimum) is deliberate: a sensor's spacings are its
  # nominal cadence plus jitter, and the minimum would lock onto the one
  # tightest pair and under-bridge everything else. The trade-off is that a
  # sensor missing more than half its buckets reports the sparser rate as
  # its cadence, widening its own limit -- but at that point "polls every
  # 10 min" and "polls every 5 min and drops half" are genuinely
  # indistinguishable from the series alone, and over-bridging a flaky
  # sensor beats breaking a slow one at every step.
  def detected_cadence_ms(labels, values)
    real_indices = values.each_index.reject { |i| values[i].nil? }
    return if real_indices.size < 3

    spacings = real_indices.each_cons(2).map { |a, b| labels[b] - labels[a] }
    spacings.sort[spacings.size / 2]
  end

  def interpolate_gap!(labels, values, start, stop, last, limit)
    span = (labels[stop] - labels[last]).to_f
    return if span > limit

    if sparse?
      # Persistent quantity: hold the last value as a flat step until the next
      # sample, rather than ramping linearly between sparse readings.
      values.fill(values[last], start...stop)
    else
      a = values[last]
      delta = values[stop] - a
      (start...stop).each do |j|
        values[j] = a + (delta * (labels[j] - labels[last]) / span)
      end
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
      pointHoverRadius: POINT_HOVER_RADIUS,
      clip: live_flash_clip,
      colorClass: color_class(sensor),
      colorScale: (sensor.color_scale if sensor.respond_to?(:color_scale)),
      hatchFill: sensor.hatch_fill?,
      noGradient: type == 'bar' || sensor.hatch_fill?,
      borderRadius: (3 if type == 'bar'),
      borderSkipped: (bar_border_skip if type == 'bar'),
      # Sparse sensors carry their last value forward, so render crisp steps
      # (vertical transitions), matching how a persistent quantity changes.
      stepped: (true if sparse?),
    }.compact
  end

  # Allow the live flash dot to overflow the right edge (positive = pixels of
  # overflow before clipping), so it isn't cut off; the other sides keep the
  # default clip at the chart area. Only the "now" chart flashes, so it's nil
  # elsewhere and dropped by #compact.
  def live_flash_clip
    return unless timeframe.now?

    { left: 0, top: 0, right: FLASH_DOT_HEADROOM, bottom: 0 }
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
      #
      # The window end stays at the exact current time, but the start is
      # snapped up to the query's 30s bucket grid: the leftmost data point
      # sits on that grid, so an un-snapped start would leave a sub-bucket
      # gap at the left edge.
      bucket = 30.seconds.in_milliseconds
      now_ms = Time.current.to_i * 1000
      grid_start = (now_ms + bucket - 1) / bucket * bucket
      options[:max] = now_ms
      options[:min] = grid_start - 1.hour.in_milliseconds
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
    # simplecov:disable
    raise NotImplementedError, 'Subclasses must implement chart_sensor_names'
    # simplecov:enable
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
    base_agg = sensor_def.default_aggregation
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
        # All other units (watt, gram, money, etc.) should be summed
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
    ).call(interpolate: interpolate?, lookback: series_lookback)
  end

  # Override this in subclasses to enable interpolation
  def interpolate?
    false
  end

  # A sensor counts as sparse/persistent when it deliberately raises its
  # max_age above the default: its readings then arrive far apart (15+ min,
  # often hours) while the measured quantity persists between them (battery
  # SOC, fill levels, meter readings). Such sensors get leading-edge seeding,
  # gap bridging up to max_age, flat-step holds and stepped rendering, so a
  # value that legitimately persists between rare samples doesn't read as a
  # gap. Dense sensors (the default) are unaffected.
  def sparse?
    return @sparse unless @sparse.nil?

    @sparse =
      chart_sensors.first&.max_age.to_i >
      Sensor::Definitions::Dsl::DEFAULT_MAX_AGE.to_i
  end

  # Extra history (a duration) fetched before the window start: a sparse
  # sensor looks back one max_age so #bridge_short_gaps can connect its last
  # pre-window sample to the first in-window one, filling the leading edge
  # instead of opening with a gap.
  def series_lookback
    sparse? ? chart_sensors.first.max_age : 0
  end

  # Override in subclasses whose sensors read 0 W while idle. Every nil left
  # after the bridge_short_gaps pass (a gap longer than #gap_bridge_limit or
  # a window edge) is set to 0, so an idle consumer renders as a flat 0
  # baseline instead of a line break.
  def fill_gaps_with_zero?
    false
  end

  # Minimum bridge limit (in ms) for server-side bridge_short_gaps and the
  # client-side Chart.js spanGaps. The actual server-side limit is widened
  # automatically for sparse sensors via #effective_gap_bridge_limit -- so
  # subclasses only need to override this to *narrow* the threshold (e.g.
  # cadence-jitter scale for the live "now" view) or to disable bridging
  # entirely by returning 0.
  #
  # A sparse sensor bridges up to its max_age, but no further: a real outage
  # beyond it (e.g. a stopped collector) stays a visible break -- consistent
  # with how Latest drops stale current values.
  def gap_bridge_limit
    sparse? ? chart_sensors.first.max_age.in_milliseconds : SPAN_GAPS_MS
  end

  # Chart.js spanGaps value for a specific dataset, mirroring the server-side
  # bridge limit so the client connects line points across gaps up to the
  # same threshold the server interpolated. Numeric spanGaps with a time
  # scale also gates the segment between *consecutive non-null* points: if
  # their X-distance exceeds the value, Chart.js breaks the line. A fixed
  # floor (e.g. 5 min) would therefore hide every step of a 15-min sensor.
  # Returning the adaptive limit keeps fast-poll outage detection while
  # letting sparse cadences (forecast, slow-poll sensors) still render.
  # Passing 0 is *not* "span nothing" -- Chart.js reads it as a 0 ms
  # threshold and breaks the line at every point. Collapse a zero
  # #gap_bridge_limit to false (the Chart.js default: never span, but still
  # draw the line).
  def compute_span_gaps_ms(labels, values)
    return false unless type == 'line'
    return false unless gap_bridge_limit.positive?

    effective_gap_bridge_limit(labels, values)
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
