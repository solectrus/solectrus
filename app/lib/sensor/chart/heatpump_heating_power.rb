class Sensor::Chart::HeatpumpHeatingPower < Sensor::Chart::Base
  def chart_sensor_names
    if timeframe.now?
      # For live data, power splitter values are not available
      %i[heatpump_power heatpump_power_env]
    else
      # For historical data, use the full power splitter breakdown
      %i[heatpump_power_grid heatpump_power_pv heatpump_power_env]
    end
  end

  private

  # Override transform_data to ensure sum of components == heating_power.
  # Sparse heating_power cadences (e.g. hourly backfills on a 5-min grid)
  # are bridged once via Base#bridge_short_gaps so we can clamp the
  # component values against the *interpolated* heating_power.
  #
  # Grid and pv often arrive at a coarser cadence than the bucket grid (the
  # power splitter writes every ~5 min). On a fine grid -- e.g. the 1-min
  # zoom on the day view -- the empty in-between buckets would otherwise be
  # forced to 0 (via `|| 0` below), collapsing the stacked PV/grid area into
  # a comb of spikes between the real samples. Bridge each component across
  # its native cadence first (same cadence-adaptive Base#bridge_short_gaps as
  # heating_power), so the split layers stay continuous. The env layer is
  # derived from heating_power - electrical and absorbs the difference, so
  # the stacked area stays consistent (sum == heating_power).
  def transform_data(data, sensor_name)
    return super unless series.respond_to?(:heatpump_heating_power)

    # Drive the output off *this* sensor's own timestamps and look up
    # heating_power by key, instead of assuming the component grid is
    # index-aligned with heating_power's. `data` is build_chart_data_item's
    # already future-trimmed value list (a prefix of the sorted points), so
    # first(data.size) picks exactly the matching timestamps.
    timestamps = component_timestamps(sensor_name).first(data.size)
    timestamps.map do |timestamp|
      heating_power = bridged_heating_power[timestamp]

      next nil if heating_power.nil?
      next 0 unless heating_power.positive?

      clamp_to_heating_power(sensor_name, heating_power, timestamp)
    end
  end

  def heating_data
    sensor_data(:heatpump_heating_power)
  end

  # heating_data with linear interpolation across short gaps, so components
  # at finer cadences can be clamped against a continuous ceiling.
  def bridged_heating_power
    @bridged_heating_power ||= bridged_by_timestamp(heating_data)
  end

  def sensor_data(sensor_name)
    (@sensor_data ||= {})[sensor_name] ||=
      if series.respond_to?(sensor_name)
        series.public_send(sensor_name, *aggregations_for_sensor(sensor_name)) || {}
      else
        {}
      end
  end

  # This sensor's own timestamps, sorted -- the output grid for transform_data
  # (see there). Memoized per sensor.
  def component_timestamps(sensor_name)
    (@component_timestamps ||= {})[sensor_name] ||= sensor_data(sensor_name).keys.sort
  end

  # A component sensor's values keyed by timestamp, with short gaps bridged
  # (see #bridged_by_timestamp for the why), memoized per sensor.
  def bridged_component(sensor_name)
    (@bridged_components ||= {})[sensor_name] ||=
      bridged_by_timestamp(sensor_data(sensor_name))
  end

  # Bridge short gaps in a {Time => value} hash via the cadence-adaptive
  # Base#bridge_short_gaps, so a coarse-cadence layer stays continuous on a
  # finer bucket grid. Only runs on the fine line grid (type == 'line', the
  # same gate the sibling stacked charts use) -- weekly / monthly / yearly bar
  # aggregates are dense by construction (SQL group_by) and use Date keys that
  # don't respond to #to_i, so we skip bridging.
  def bridged_by_timestamp(data)
    return data unless type == 'line'

    timestamps = data.keys.sort
    return data if timestamps.size < 2

    labels = timestamps.map { |t| timestamp_to_ms(t) }
    values = timestamps.map { |t| data[t] }
    timestamps.zip(bridge_short_gaps(labels, values)).to_h
  end

  def clamp_to_heating_power(sensor_name, heating_power, timestamp)
    case sensor_name
    when :heatpump_power_grid, :heatpump_power
      [component_value(sensor_name, timestamp), heating_power].min
    when :heatpump_power_pv
      _grid, pv = clamped_grid_pv(heating_power, timestamp)
      pv
    when :heatpump_power_env
      clamp_env_power(heating_power, timestamp)
    else
      component_value(sensor_name, timestamp)
    end
  end

  # A bridged component value at a timestamp, defaulting to 0 when absent.
  def component_value(sensor_name, timestamp)
    bridged_component(sensor_name)[timestamp] || 0
  end

  # Grid and PV contributions, each clamped so their running sum never
  # exceeds heating_power (grid takes priority, PV fills the remainder).
  # Returns [grid_clamped, pv_clamped].
  def clamped_grid_pv(heating_power, timestamp)
    grid = component_value(:heatpump_power_grid, timestamp)
    pv = component_value(:heatpump_power_pv, timestamp)
    grid_clamped = [grid, heating_power].min
    pv_clamped = [pv, heating_power - grid_clamped].min
    [grid_clamped, pv_clamped]
  end

  def clamp_env_power(heating_power, timestamp)
    electrical =
      if timeframe.now?
        # There is no power splitter for live data, so just clamp to heating power
        [component_value(:heatpump_power, timestamp), heating_power].min
      else
        # Clamp to the remaining power after grid and PV contributions
        clamped_grid_pv(heating_power, timestamp).sum
      end

    [heating_power - electrical, 0].max
  end

  def datasets(chart_data_items)
    chart_data_items.map do |chart_data|
      sensor = Sensor::Registry[chart_data[:sensor_name]]

      {
        id: sensor.name,
        label: dataset_label(sensor),
        data: chart_data[:data],
        colorClass: sensor.color_background,
        borderWidth: 1,
        stack: 'HeatingPower',
        borderRadius: (timeframe.short? ? nil : BORDER_RADIUS[sensor.name]),
        fill: fill_mode_for_sensor(sensor),
        tension: 0.4,
        cubicInterpolationMode: 'monotone',
        pointRadius: 0,
        pointHoverRadius: 5,
        noGradient: true,
      }
    end
  end

  def dataset_label(sensor)
    if timeframe.now? && sensor.name == :heatpump_power
      I18n.t('splitter.total')
    else
      sensor.display_name
    end
  end

  def fill_mode_for_sensor(sensor)
    case sensor.name
    when :heatpump_power_grid, :heatpump_power
      'origin' # Fill from zero baseline
    else
      '-1' # Fill to previous dataset
    end
  end

  BORDER_RADIUS = {
    heatpump_power_grid: {
      bottomLeft: 3,
      bottomRight: 3,
      topLeft: 0,
      topRight: 0,
    },
    heatpump_power_pv: 0,
    heatpump_power_env: {
      bottomLeft: 0,
      bottomRight: 0,
      topLeft: 3,
      topRight: 3,
    },
  }.freeze
  private_constant :BORDER_RADIUS
end
