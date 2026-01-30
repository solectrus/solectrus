class HeatmapTile::Component < ViewComponent::Base
  def initialize(data:, sensor:, timeframe:)
    super()
    @data = data
    @sensor = sensor
    @timeframe = timeframe
  end

  attr_reader :data, :sensor, :timeframe

  private

  def years
    timeframe.year? ? [] : data.keys.sort
  end

  def months
    timeframe.year? ? data.keys.sort : []
  end

  def value_for(year, month)
    return unless timeframe.all?

    data.dig(year, month)
  end

  def daily_value_for(month, day)
    return unless timeframe.year?

    data.dig(month, day)
  end

  def current_year
    timeframe.year? ? timeframe.date.year : Date.current.year
  end

  def max_value
    @max_value ||= calculate_max_value
  end

  def min_value
    @min_value ||= calculate_min_value
  end

  def calculate_max_value
    all_values = data.values.flat_map(&:values).compact

    return grid_max_value(all_values) if grid_power?

    sensor_max_value(all_values)
  end

  def calculate_min_value
    return 0 if grid_power?

    all_values = data.values.flat_map(&:values).compact
    sensor_min_value(all_values)
  end

  def grid_max_value(all_values)
    all_values.map { |value| grid_balance(value).abs }.max || 0
  end

  def sensor_max_value(all_values)
    values = use_range_based_opacity? ? all_values.reject(&:zero?) : all_values
    values.max || 0
  end

  def sensor_min_value(all_values)
    values = use_range_based_opacity? ? all_values.reject(&:zero?) : all_values
    values.min || 0
  end

  def use_range_based_opacity?
    sensor.allowed_aggregations.first == :avg
  end

  def grid_power?
    sensor.name == :grid_power
  end

  def grid_fields
    %i[grid_revenue grid_costs]
  end

  def grid_balance(value)
    return 0 unless value.is_a?(Hash)

    value[:grid_balance]
  end

  def background_class(value)
    if value.nil? || (value.respond_to?(:zero?) && value.zero?)
      return 'bg-inherit'
    end
    return 'bg-inherit' if grid_power? && grid_balance(value).zero?

    grid_power? ? grid_balance_color(value) : sensor_background_color
  end

  def opacity(value)
    return if value.nil? || (value.respond_to?(:zero?) && value.zero?)
    return if grid_power? && grid_balance(value).zero?

    (grid_power? ? grid_balance_opacity(value) : standard_opacity(value)).round(
      2,
    )
  end

  def grid_balance_color(value)
    balance = grid_balance(value)

    if balance.positive?
      sensor_background_color(:grid_export_power)
    else
      sensor_background_color(:grid_import_power)
    end
  end

  def grid_balance_opacity(value)
    balance = grid_balance(value)
    return 0.5 if max_value.zero?

    balance.abs.fdiv(max_value).clamp(0, 1)
  end

  def standard_opacity(value)
    return 0.5 if max_value.zero?

    if use_range_based_opacity?
      # For avg aggregations (like COP), use range-based opacity for better contrast
      # Zero values (e.g., no heating) should remain invisible
      return 0 if value.zero?

      range = max_value - min_value
      return 0.5 if range.zero?

      # Scale opacity from 0.2 (min) to 1.0 (max) for better visibility
      normalized = (value - min_value).fdiv(range).clamp(0, 1)
      ((normalized * 0.8) + 0.2).round(2)
    else
      # For sum aggregations, use absolute opacity
      value.fdiv(max_value).clamp(0, 1)
    end
  end

  def sensor_background_color(sensor_name = sensor.name)
    current_sensor = Sensor::Registry[sensor_name]

    # Use consistent color for all consumer sensors (house_power, custom_power, etc.)
    return 'bg-slate-500 dark:bg-slate-500' if current_sensor.category == :consumer

    current_sensor.color_background
  end

  def link_path_for_date(date)
    timeframe = date.respond_to?(:strftime) ? date.strftime('%Y-%m-%d') : date
    sensor_name = sensor.name

    case sensor.category
    when :heatpump
      helpers.heatpump_home_path(sensor_name:, timeframe:)
    when :house
      helpers.house_home_path(sensor_name:, timeframe:)
    when :inverter
      helpers.inverter_home_path(sensor_name:, timeframe:)
    else
      helpers.balance_home_path(sensor_name:, timeframe:)
    end
  end
end
