class Sensor::Chart::HeatpumpCopScatter < Sensor::Chart::Base # rubocop:disable Metrics/ClassLength
  MIN_RADIUS = 3
  MAX_RADIUS = 12
  private_constant :MIN_RADIUS, :MAX_RADIUS

  def type = 'scatter'
  def chart_sensor_names = %i[heatpump_cop outdoor_temp heatpump_power]
  def label = I18n.t('charts.heatpump_cop_scatter.title')

  def options
    {
      maintainAspectRatio: false,
      plugins: {
        legend: false,
        tooltip: {
          **tooltip_options,
          mode: 'nearest',
          intersect: true,
        },
        zoom: {
          zoom: {
            drag: {
              enabled: true,
            },
            mode: 'xy',
          },
        },
        crosshair: false,
      },
      animation: {
        easing: 'easeOutQuad',
        duration: 300,
      },
      elements: {
        point: {
          hitRadius: 10,
          hoverBorderWidth: 2,
        },
      },
      scales: {
        x: {
          type: 'linear',
          ticks: {
            callback: 'formatTemperature',
          },
          grid: {
            color: 'zeroLineHighlight',
          },
        },
        y: {
          suggestedMin: 0,
          suggestedMax: 6,
        },
      },
    }
  end

  private

  def sql_aggregations_for_sensor(sensor_name)
    case sensor_name
    when :heatpump_power
      %i[sum sum]
    else
      %i[avg avg]
    end
  end

  def sql_grouping_period = :day

  def build_data
    # Scatter chart doesn't make sense for "now" - no distribution data
    return if timeframe.now?

    return unless series

    points = build_scatter_points
    return if points.empty?

    { datasets: [scatter_dataset(points)] }
  end

  # For single day, use InfluxDB with hourly aggregation
  def use_sql_for_timeframe?
    !timeframe.short?
  end

  # Override InfluxDB series to use hourly aggregation for scatter chart
  def build_influx_series
    Sensor::Query::Series.new(
      chart_sensor_names,
      timeframe,
      interval: '1h',
      timestamp_method: :to_time,
    ).call(interpolate: false)
  end

  def build_scatter_points
    cop_data = series.heatpump_cop(:avg, :avg) || {}
    temp_data = series.outdoor_temp(:avg, :avg) || {}
    power_data = fetch_power_data

    cop_data.filter_map do |time_key, cop|
      next if skip_time_key?(time_key)

      build_point(time_key, cop, temp_data, power_data, max_power_for_timeframe)
    end
  end

  def skip_time_key?(time_key)
    return false unless timeframe.short?

    # Skip incomplete hours (non-zero minutes indicate partial data)
    return true if time_key.min != 0

    # Skip future timestamps (incomplete data for current/future hours)
    time_key >= Time.current.beginning_of_hour
  end

  def fetch_power_data
    # For multi-day: use sum aggregation from SQL
    # For single day: use avg from InfluxDB (in W, same as hourly Wh)
    if timeframe.short?
      series.heatpump_power(:avg, :avg) || {}
    else
      series.heatpump_power(:sum, :sum) || {}
    end
  end

  def max_power_for_timeframe
    timeframe.short? ? max_hourly_power : global_max_power
  end

  def max_hourly_power
    @max_hourly_power ||=
      begin
        raw_power = series.heatpump_power(:avg, :avg) || {}
        raw_power.values.compact.max || 1
      end
  end

  def global_max_power
    @global_max_power ||=
      Rails
        .cache
        .fetch('heatpump_power:max_daily_P365D', expires_in: 1.hour) do
          ranking =
            Sensor::Query::Ranking.new(
              :heatpump_power,
              aggregation: :sum,
              period: :day,
              desc: true,
              limit: 1,
              start: 365.days.ago.to_date,
              stop: Date.current,
            )
          result = ranking.call.first
          result ? result[:value] : 1
        end
  end

  def build_point(time_key, cop, temp_data, power_data, max_power)
    return unless valid_cop?(cop)

    temp = temp_data[time_key]
    return unless temp

    power = power_data[time_key] || 0

    point = {
      x: temp.round(1),
      y: cop.round(2),
      timestamp: timestamp_to_ms(time_key),
      power: power.round(0),
      r: calculate_radius(power, max_power),
    }

    # Only add drilldown for multi-day views
    point[:drilldownPath] = drilldown_path(time_key) unless timeframe.short?
    point
  end

  def drilldown_path(time_key)
    Rails.application.routes.url_helpers.heatpump_home_path(
      sensor_name: :heatpump_cop,
      timeframe: time_key.to_date.iso8601,
    )
  end

  def valid_cop?(cop) = cop&.positive? && cop <= 8

  def calculate_radius(heating, max_heating)
    return MIN_RADIUS unless heating.positive? && max_heating.positive?

    normalized = heating.to_f / max_heating
    ((normalized * (MAX_RADIUS - MIN_RADIUS)) + MIN_RADIUS).round(1)
  end

  def scatter_dataset(points)
    radii = points.pluck(:r)
    {
      id: 'cop_scatter',
      label: I18n.t('charts.cop_scatter'),
      data: points,
      colorClass: cop_sensor.color_chart,
      borderWidth: 1,
      pointRadius: radii,
      pointHoverRadius: radii,
      # Tooltip field definitions (order determines display order)
      tooltipFields: tooltip_fields,
      # Show time in tooltip for hourly data (day view)
      showTime: timeframe.short?,
    }
  end

  def temp_sensor = @temp_sensor ||= Sensor::Registry[:outdoor_temp]
  def cop_sensor = @cop_sensor ||= Sensor::Registry[:heatpump_cop]
  def power_sensor = @power_sensor ||= Sensor::Registry[:heatpump_power]

  def tooltip_fields
    [
      {
        source: 'x',
        name: temp_sensor.display_name,
        unit: format_unit(temp_sensor.unit),
      },
      {
        source: 'y',
        name: cop_sensor.display_name,
        unit: format_unit(cop_sensor.unit),
      },
      {
        source: 'data',
        dataKey: 'power',
        name: I18n.t('charts.heatpump_cop_scatter.heatpump_power'),
        unit: format_unit(power_sensor.unit, context: :total),
        transform: 'divideBy1000',
      },
    ]
  end

  def format_unit(unit, context: :rate)
    Sensor::UnitFormatter.format(unit:, context:, scaling: :kilo)
  end
end
