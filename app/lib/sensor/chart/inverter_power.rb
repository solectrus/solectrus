class Sensor::Chart::InverterPower < Sensor::Chart::Base
  def initialize(timeframe:, variant: nil)
    super(timeframe:)
    @variant = variant
  end

  attr_reader :variant

  # Include individual inverters (stacked) or total, plus forecast sensors
  def chart_sensor_names
    sensors = stackable? ? stacked_sensors : [:inverter_power]
    sensors + forecast_sensors
  end

  # For stacked view: mask past forecast values to reduce visual clutter
  # For non-stacked view: show full forecast for the entire day
  def build_chart_data_item(sensor_name)
    if sensor_name == :inverter_power_forecast && timeframe.today? && stackable?
      build_remaining_forecast_data_item(sensor_name)
    else
      super
    end
  end

  # Override datasets to provide stacked multi-inverter datasets
  def datasets(chart_data_items)
    if stackable?
      # Simple: show all sensors that have data
      chart_data_items.map { |item| build_dataset(item[:sensor_name], item) }
    else
      super # Use base class implementation
    end
  end

  # Stackable when multi-inverter is configured and variant is 'split'
  def stackable?
    Sensor::Config.multi_inverter? && ApplicationPolicy.multi_inverter? &&
      individual_inverter_sensors.any? && variant == 'split'
  end

  # Individual inverter sensors (excluding the main inverter_power)
  def individual_inverter_sensors
    @individual_inverter_sensors ||=
      Sensor::Config.custom_inverter_sensors.map(&:name)
  end

  # Enable interpolation for forecast data
  def interpolate?
    true
  end

  #
  # Forecast data for ForecastComment
  #

  # Remaining forecast energy in Wh for today
  def remaining_forecast_wh
    return unless timeframe.today? && forecast_series_data

    @remaining_forecast_wh ||=
      Sensor::Forecast::TodayAnalyzer.new(forecast_series_data).remaining_wh
  end

  # Total forecast for the day (sum of hourly values)
  def inverter_power_forecast
    @inverter_power_forecast ||= sum_series(:inverter_power_forecast)
  end

  # Total actual power for the day (sum of hourly values)
  def inverter_power
    @inverter_power ||= sum_series(:inverter_power)
  end

  # Deviation between actual and forecast
  def forecast_deviation
    return unless inverter_power && inverter_power_forecast

    (inverter_power - inverter_power_forecast).round
  end

  private

  def stacked_sensors
    if timeframe.now?
      # Render live data without difference sensor
      individual_inverter_sensors
    else
      # Historical data may contain differences between total and sum of individuals
      [*individual_inverter_sensors, :inverter_power_difference]
    end
  end

  # For today: forecast as hatched area, plus clearsky line if not stacked
  # For other days: forecast lines only in non-stacked view
  def forecast_sensors
    return [] unless timeframe.day?
    return [] if stackable? && !timeframe.today?

    names = [:inverter_power_forecast]
    names << :inverter_power_forecast_clearsky unless stackable?
    names.select { |name| Sensor::Config.exists?(name) }
  end

  def forecast_series_data
    return unless series&.raw_data

    @forecast_series_data ||=
      series
        .raw_data
        .find { |key, _| key.first == :inverter_power_forecast }
        &.last
  end

  def sum_series(sensor_name)
    return unless series.respond_to?(sensor_name)

    aggregations = aggregations_for_sensor(sensor_name)
    points_hash = series.public_send(sensor_name, *aggregations)
    return unless points_hash

    # InfluxDB data is power values (W) - calculate energy using proper integration
    entries =
      points_hash
        .sort_by { |time_key, _| time_key }
        .map { |time_key, value| [normalize_timestamp(time_key), value] }

    Sensor::Forecast::EnergyCalculator.calculate_wh(entries)
  end

  def style_for_sensor(sensor)
    case sensor.name
    when :inverter_power_forecast_clearsky
      {
        borderWidth: 1,
        borderDash: [2, 3], # Dotted line pattern
        fill: false,
        colorClass: sensor.color_chart,
      }
    when :inverter_power_forecast
      timeframe.today? ? hatched_forecast_style(sensor) : super
    else
      super.merge(
        noGradient: stackable?,
      )
    end
  end

  # Hatched fill style for remaining forecast area
  def hatched_forecast_style(sensor)
    {
      tension: 0.4,
      cubicInterpolationMode: 'monotone',
      borderWidth: 0.3,
      colorClass: sensor.color_chart,
      fill: true,
      noGradient: true,
      hatchFill: true,
    }
  end

  # Build forecast data item with past values masked (nil)
  def build_remaining_forecast_data_item(sensor_name)
    points_hash =
      series.public_send(sensor_name, *aggregations_for_sensor(sensor_name))
    return empty_dataset(sensor_name) unless points_hash

    sorted_points = points_hash.sort_by { |time_key, _| time_key }

    {
      sensor_name:,
      labels: sorted_points.map { |time_key, _| timestamp_to_ms(time_key) },
      data: mask_past_values(sorted_points, sensor_name),
    }
  end

  # Set past values to nil so only future forecast is displayed
  def mask_past_values(sorted_points, sensor_name)
    now = Time.current
    data_values = transform_data(sorted_points.map(&:second), sensor_name)

    sorted_points.zip(data_values).map! do |(time_key, _), value|
      normalize_timestamp(time_key) >= now ? value : nil
    end
  end

  def build_dataset(sensor_name, chart_data)
    sensor = Sensor::Registry[sensor_name]

    {
      id: sensor.name,
      label: sensor.display_name,
      data: chart_data[:data],
      stack: (sensor.category == :forecast ? nil : 'InverterPower'),
    }.compact.merge(style_for_sensor(sensor))
  end
end
