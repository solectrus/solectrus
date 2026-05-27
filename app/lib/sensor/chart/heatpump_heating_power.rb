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
  # component values against the *interpolated* heating_power. Grid and
  # pv therefore keep their native (often denser) cadence; the env layer
  # is derived from heating_power - electrical and absorbs the difference,
  # so the stacked area stays consistent (sum == heating_power) while
  # grid/pv reveal their actual resolution.
  def transform_data(data, sensor_name)
    return super unless series.respond_to?(:heatpump_heating_power)

    timestamps = heating_data.keys.sort
    data.map.with_index do |value, index|
      timestamp = timestamps[index]
      heating_power = bridged_heating_power[timestamp]

      next nil if heating_power.nil?
      next 0 unless heating_power.positive?

      clamp_to_heating_power(sensor_name, value || 0, heating_power, timestamp)
    end
  end

  def heating_data
    @heating_data ||= sensor_data(:heatpump_heating_power)
  end

  # heating_data with linear interpolation across short gaps, so components
  # at finer cadences can be clamped against a continuous ceiling. Reuses
  # Base#bridge_short_gaps (cadence-adaptive limit applies). Only meaningful
  # for sub-day timeframes (line charts on a fine bucket grid) -- weekly /
  # monthly / yearly aggregates are dense by construction (SQL group_by)
  # and use Date keys that don't respond to #to_i, so we skip bridging.
  def bridged_heating_power
    @bridged_heating_power ||= build_bridged_heating_power
  end

  def build_bridged_heating_power
    return heating_data unless timeframe.short?

    timestamps = heating_data.keys.sort
    return heating_data if timestamps.size < 2

    labels = timestamps.map { |t| t.to_i * 1000 }
    values = timestamps.map { |t| heating_data[t] }
    timestamps.zip(bridge_short_gaps(labels, values)).to_h
  end

  def sensor_data(sensor_name)
    return {} unless series.respond_to?(sensor_name)

    aggregations = aggregations_for_sensor(sensor_name)
    series.public_send(sensor_name, *aggregations) || {}
  end

  def clamp_to_heating_power(sensor_name, value, heating_power, timestamp)
    case sensor_name
    when :heatpump_power_grid, :heatpump_power
      [value, heating_power].min
    when :heatpump_power_pv
      grid = sensor_data(:heatpump_power_grid)[timestamp] || 0
      grid_clamped = [grid, heating_power].min
      [value, heating_power - grid_clamped].min
    when :heatpump_power_env
      clamp_env_power(heating_power, timestamp)
    else
      value
    end
  end

  def clamp_env_power(heating_power, timestamp)
    electrical =
      if timeframe.now?
        # There is no power splitter for live data, so just clamp to heating power
        [sensor_data(:heatpump_power)[timestamp] || 0, heating_power].min
      else
        # Clamp to the remaining power after grid and PV contributions
        grid = sensor_data(:heatpump_power_grid)[timestamp] || 0
        pv = sensor_data(:heatpump_power_pv)[timestamp] || 0
        grid_clamped = [grid, heating_power].min
        pv_clamped = [pv, heating_power - grid_clamped].min
        grid_clamped + pv_clamped
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
