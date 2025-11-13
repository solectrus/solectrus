class Sensor::Chart::InverterPowerForecast < Sensor::Chart::Base # rubocop:disable Metrics/ClassLength
  LABEL_FONT = 'bold 14px Inter Variable, sans-serif'.freeze
  LABEL_COLOR = '#475569'.freeze
  LABEL_FONT_SMALL = 'bold 12px Inter Variable, sans-serif'.freeze
  MIN_DAY_HOURS = 8 # Minimum hours of data to consider a day valid

  private_constant :LABEL_FONT, :LABEL_COLOR, :LABEL_FONT_SMALL, :MIN_DAY_HOURS

  def chart_sensor_names
    Sensor::Config.sensors.filter_map do |sensor|
      sensor.name if sensor.category == :forecast
    end
  end

  def type
    'line'
  end

  def unit
    return if chart_sensors.none?

    @unit ||=
      Sensor::UnitFormatter.format(
        unit: chart_sensors.first.unit,
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

    super.merge(
      interaction: {
        intersect: false, # Enable tooltips at any x-position
        mode: 'index',
      },
      layout: {
        padding: {
          bottom: 55, # Extra space for custom x-axis labels
        },
      },
      plugins:
        super[:plugins].merge(
          customXAxisLabels: {
            enabled: true,
            labels: x_axis_labels,
          },
        ),
    )
  end

  private

  def build_series_data
    return if chart_sensor_names.empty?

    result =
      Sensor::Query::Series.new(
        chart_sensor_names,
        timeframe,
        timestamp_method: :to_time,
        interval: '15m',
      ).call(interpolate: true)

    add_boundary_zeros(result) if result
    result
  end

  def add_boundary_zeros(series)
    series.raw_data.each_value do |data|
      group_by_date(data).each_value do |day_entries|
        add_day_boundaries(day_entries, data)
      end
    end
  end

  def group_by_date(data)
    data.group_by { |timestamp, _| timestamp.to_date }
  end

  def add_day_boundaries(day_entries, data)
    non_zero_timestamps = extract_non_zero_timestamps(day_entries)
    return if non_zero_timestamps.empty?

    data[non_zero_timestamps.first - 15.minutes] ||= 0.0
    data[non_zero_timestamps.last + 15.minutes] ||= 0.0
  end

  def extract_non_zero_timestamps(day_entries)
    day_entries
      .filter_map { |timestamp, value| timestamp if value&.abs&.>(0.01) }
      .sort
  end

  def x_time_options
    { tooltipFormat: 'cccc, HH:mm', unit: 'day' }
  end

  def x_scale_options
    return super unless forecast_sensor_data

    tick_positions = x_axis_labels.pluck(:x)

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
      },
      customTickPositions: tick_positions,
    )
  end

  def x_axis_labels
    @x_axis_labels ||=
      forecast_data.map do |date, data|
        {
          x: data[:noon_timestamp],
          lines: [day_label(date), *kwh_labels(data[:total_kwh])],
        }
      end
  end

  def day_label(date)
    {
      text: I18n.l(date, format: '%a'),
      md: {
        text: I18n.l(date, format: '%A'),
      },
      offsetY: 14,
    }
  end

  def kwh_labels(kwh)
    return [] unless kwh&.positive?

    [kwh_value_label(kwh), kwh_unit_label]
  end

  def kwh_value_label(kwh)
    {
      text: kwh.to_s,
      font: LABEL_FONT,
      color: LABEL_COLOR,
      offsetY: 40,
      md: {
        text: "#{kwh} kWh",
        font: LABEL_FONT,
        color: LABEL_COLOR,
        offsetY: 32,
      },
    }
  end

  def kwh_unit_label
    {
      text: 'kWh',
      font: LABEL_FONT_SMALL,
      color: LABEL_COLOR,
      offsetY: 54,
      md: nil,
    }
  end

  def forecast_data
    @forecast_data ||=
      if forecast_sensor_data
        forecast_sensor_data
          .group_by { |timestamp, _| timestamp.to_date }
          .filter_map { |date, entries| build_day_data(date, entries) }
          .to_h
      else
        {}
      end
  end

  def build_day_data(date, entries)
    return if entries.size < 2

    timestamps = entries.map(&:first)
    time_span_hours = (timestamps.max - timestamps.min) / 3600.0
    return if time_span_hours < MIN_DAY_HOURS

    noon = timestamps.min_by { |t| (t.hour - 12).abs }
    total_kwh =
      day_complete?(entries, time_span_hours) ? calculate_kwh(entries) : nil

    [date, { noon_timestamp: noon.to_i * 1000, total_kwh: }]
  end

  def day_complete?(entries, time_span_hours)
    first_value = entries.first.last
    first_value&.abs&.<=(10) && time_span_hours >= MIN_DAY_HOURS
  end

  # Calculate total energy (kWh) from power measurements using numerical integration
  # Uses the left endpoint rule (left Riemann sum) to integrate power over time:
  # Energy = integral(Power dt) ~= sum(Power_i * delta_t_i)
  def calculate_kwh(entries)
    return 0 if entries.size < 2

    total_wh =
      entries
        .sort_by(&:first)
        .each_cons(2)
        .sum do |(t1, power), (t2, _)|
          interval_hours = (t2 - t1) / 3600.0
          power * interval_hours # Wh for this interval
        end

    (total_wh / 1000.0).round # Convert Wh to kWh
  end

  def min_timestamp
    return unless forecast_sensor_data

    forecast_sensor_data.keys.min.beginning_of_day.to_i * 1000
  end

  def max_timestamp
    return unless forecast_sensor_data

    last_noon = forecast_data.values.last&.[](:noon_timestamp)
    end_time =
      if last_noon
        Time.zone.at(last_noon / 1000).end_of_day
      else
        forecast_sensor_data.keys.max.end_of_day
      end

    end_time.to_i * 1000
  end

  def forecast_sensor_data
    @forecast_sensor_data ||=
      series
        &.raw_data
        &.find { |key, _| key.first == :inverter_power_forecast }
        &.last
  end

  def style_for_sensor(sensor)
    return super unless sensor.name == :inverter_power_forecast_clearsky

    {
      borderWidth: 1,
      borderDash: [2, 3],
      fill: false,
      backgroundColor: sensor.color_hex,
    }
  end
end
