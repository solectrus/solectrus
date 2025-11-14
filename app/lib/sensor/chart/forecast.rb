class Sensor::Chart::Forecast < Sensor::Chart::Base # rubocop:disable Metrics/ClassLength
  FORECAST_SENSOR_NAMES = %i[
    inverter_power
    inverter_power_forecast
    inverter_power_forecast_clearsky
    outdoor_temp_forecast
  ].freeze
  private_constant :FORECAST_SENSOR_NAMES

  def chart_sensor_names
    Sensor::Config.sensors.filter_map do |sensor|
      sensor.name if sensor.name.in?(FORECAST_SENSOR_NAMES)
    end
  end

  def type
    'line'
  end

  def unit
    return if chart_sensors.none?

    # Get unit from first non-temperature sensor (not on y1 axis)
    main_sensor =
      chart_sensors.find { |s| s.name != :outdoor_temp_forecast } ||
        chart_sensors.first

    @unit ||=
      Sensor::UnitFormatter.format(
        unit: main_sensor.unit,
        context: :rate, # Always show as rate (kW), not total (kWh)
      )
  end

  def use_sql_for_timeframe?
    false # Always use InfluxDB for forecast data
  end

  def actual_days
    forecast_data.size.clamp(1, 14)
  end

  def options
    return super unless forecast_sensor_data

    opts =
      super.merge(
        interaction: {
          intersect: false,
          mode: 'index',
        },
        layout: {
          padding: {
            bottom: 80,
          },
        }, # Extra space for custom x-axis labels
        plugins:
          super[:plugins].merge(
            customXAxisLabels: {
              enabled: true,
              labels: x_axis_labels,
            },
          ),
      )

    # Add right Y-axis for temperature if temperature sensor exists
    if Sensor::Config.exists?(:outdoor_temp_forecast)
      opts[:scales][:y1] = y1_scale_options
    end

    opts
  end

  private

  # Override to add boundary zeros to forecast data
  def build_influx_series
    Sensor::Query::Series
      .new(
        chart_sensor_names,
        timeframe,
        timestamp_method: :to_time,
        interval: '15m',
      )
      .call(interpolate: true)
      &.tap do |result|
        # Only add boundaries for power sensors, not for temperature
        power_sensor_data =
          result.raw_data.reject do |key, _|
            key.first == :outdoor_temp_forecast
          end
        BoundaryAdjuster.add_boundaries!(power_sensor_data)
      end
  end

  def x_time_options
    { tooltipFormat: 'cccc, HH:mm', unit: 'day' }
  end

  def x_scale_options
    return super unless forecast_sensor_data

    super.merge(
      min: min_timestamp,
      max: max_timestamp,
      grid: {
        drawOnChartArea: false,
        drawTicks: false,
      },
      ticks: {
        maxRotation: 0,
        autoSkip: false,
        display: false, # Hide default ticks (dates), show only custom labels
      },
    )
  end

  def x_axis_labels
    @x_axis_labels ||= label_builder.build_labels
  end

  def forecast_data
    @forecast_data ||= build_forecast_data
  end

  def build_forecast_data
    return {} unless forecast_sensor_data

    forecast_sensor_data
      .group_by { |timestamp, _| timestamp.to_date }
      .filter_map { |date, entries| build_day_entry(date, entries) }
      .reject { |date, _| date == Date.current && !today_analyzer.show_today? }
      .to_h
  end

  def build_day_entry(date, entries)
    day_forecast = DayForecast.new(date, entries)
    return unless day_forecast.valid?

    [
      date,
      {
        noon_timestamp: day_forecast.noon_timestamp_ms,
        total_kwh: day_forecast.total_kwh,
      },
    ]
  end

  def min_timestamp
    x_timestamps.min&.to_i&.*(1000)
  end

  def max_timestamp
    x_timestamps.max&.to_i&.*(1000)
  end

  def x_timestamps
    @x_timestamps ||=
      series.raw_data.values.flat_map { |data| data.map(&:first) }.compact
  end

  def forecast_sensor_data
    @forecast_sensor_data ||=
      series
        &.raw_data
        &.find { |key, _| key.first == :inverter_power_forecast }
        &.last
  end

  def today_analyzer
    @today_analyzer ||= TodayAnalyzer.new(forecast_sensor_data)
  end

  def label_builder
    @label_builder ||= LabelBuilder.new(forecast_data, today_analyzer)
  end

  def y1_scale_options
    {
      position: 'right',
      grid: {
        drawOnChartArea: false,
      },
      ticks: {
        maxTicksLimit: 10,
      },
    }
  end

  def style_for_sensor(sensor)
    case sensor.name
    when :inverter_power_forecast_clearsky
      {
        borderWidth: 1,
        borderDash: [2, 3],
        fill: false,
        backgroundColor: sensor.color_hex,
      }
    when :inverter_power
      # Actual power: solid line with fill
      super.merge(fill: true)
    when :outdoor_temp_forecast
      # Temperature: thin line on right axis
      super.merge(fill: false, borderWidth: 2, yAxisID: 'y1', opacity: 0.4)
    else
      super
    end
  end
end
