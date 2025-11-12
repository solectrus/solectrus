class Sensor::Chart::InverterPowerForecast < Sensor::Chart::Base # rubocop:disable Metrics/ClassLength
  LABEL_FONT = 'bold 14px Inter Variable, sans-serif'.freeze
  LABEL_COLOR = '#475569'.freeze
  LABEL_FONT_SMALL = 'bold 12px Inter Variable, sans-serif'.freeze

  private_constant :LABEL_FONT, :LABEL_COLOR, :LABEL_FONT_SMALL

  def chart_sensor_names
    %i[
      inverter_power_forecast
      inverter_power_forecast_clearsky
    ].select { |sensor_name| Sensor::Config.exists?(sensor_name) }
  end

  def type
    'line'
  end

  def unit
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
    # Return number of days with forecast data (1-14 days)
    noon_tick_positions.size.clamp(1, 14)
  end

  def options
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
            labels: x_axis_label_data,
          },
        ),
    )
  end

  def x_axis_label_data
    forecast_data.map do |date, data|
      {
        x: data[:noon_timestamp],
        lines: [
          {
            text: I18n.l(date, format: '%a'),
            md: {
              text: I18n.l(date, format: '%A'),
            },
            offsetY: 14,
          },
          *kwh_label_lines(data[:total_kwh]),
        ],
      }
    end
  end

  def kwh_label_lines(kwh)
    return [] unless kwh.positive?

    [
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
      },
      {
        text: 'kWh',
        font: LABEL_FONT_SMALL,
        color: LABEL_COLOR,
        offsetY: 54,
        md: nil,
      },
    ]
  end

  private

  def build_series_data
    Sensor::Query::Series.new(
      chart_sensor_names,
      timeframe,
      timestamp_method: :to_time,
      interval: '15m',
    ).call(interpolate: true)
  end

  def x_time_options
    { tooltipFormat: 'cccc, HH:mm', unit: 'day' }
  end

  def x_scale_options
    super.merge(
      {
        min: min_timestamp,
        max: max_timestamp,
        grid: {
          drawOnChartArea: false,
          drawTicks: false,
        },
        ticks: {
          maxRotation: 0,
          autoSkip: false,
          callback: -> { '' }, # Hide default tick labels (custom labels rendered via plugin)
        },
        customTickPositions: noon_tick_positions,
      }.compact,
    )
  end

  # Cached computation of all forecast data per day
  # Returns: { date => { noon_timestamp: ms, total_kwh: float, timestamps: [] } }
  def forecast_data
    @forecast_data ||= build_forecast_data
  end

  def noon_tick_positions
    @noon_tick_positions ||= forecast_data.values.pluck(:noon_timestamp)
  end

  def build_forecast_data
    return {} unless forecast_sensor_data

    # Group data by date and calculate everything in one pass
    forecast_sensor_data
      .group_by { |timestamp, _| timestamp.to_date }
      .each_with_object({}) do |(date, entries), result|
        day_data = build_day_data(entries)
        result[date] = day_data if day_data
      end
      .sort
      .to_h
  end

  def build_day_data(entries)
    return if entries.size < 2

    timestamps = entries.map(&:first)

    # Check if we have data spanning at least 20 hours
    # (allows for some missing data points but ensures it's a "complete" day)
    time_span_hours = (timestamps.max - timestamps.min) / 3600.0
    return if time_span_hours < 20

    noon = timestamps.min_by { |t| (t.hour - 12).abs }

    # Calculate total kWh based on actual data point interval
    # Formula: W * (hours between measurements) / 1000 = kWh
    total_kwh = calculate_total_kwh(entries)

    { timestamps:, noon_timestamp: noon.to_i * 1000, total_kwh: }
  end

  # Calculates total energy using rectangular rule (Riemann sum):
  # E = sum(P * delta_t) for each measurement interval
  def calculate_total_kwh(entries)
    return 0 if entries.size < 2

    sorted_entries = entries.sort_by(&:first)

    # Sum power * time_interval for each consecutive pair
    total_wh =
      sorted_entries
        .each_cons(2)
        .sum do |(t1, power), (t2, _)|
          interval_hours = (t2 - t1) / 3600.0
          power * interval_hours
        end

    (total_wh / 1000.0).round # Convert Wh to kWh
  end

  def min_timestamp
    return unless forecast_sensor_data

    forecast_sensor_data.keys.min.to_i * 1000
  end

  def max_timestamp
    return if noon_tick_positions.empty?

    Time.zone.at(noon_tick_positions.last / 1000).end_of_day.to_i * 1000
  end

  def forecast_sensor_data
    @forecast_sensor_data ||= extract_forecast_data
  end

  def extract_forecast_data
    return unless series&.raw_data

    key = series.raw_data.keys.find { |k| k.first == :inverter_power_forecast }
    series.raw_data[key] if key
  end

  def style_for_sensor(sensor)
    if sensor.name == :inverter_power_forecast_clearsky
      {
        borderWidth: 1,
        borderDash: [2, 3], # Dotted line pattern
        fill: false,
        backgroundColor: sensor.color_hex,
      }
    else
      super
    end
  end
end
