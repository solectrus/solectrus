class HeatmapTile::Component < ViewComponent::Base
  def initialize(data:, sensor:, timeframe:)
    super()
    @data = data
    @sensor = sensor
    @timeframe = timeframe
  end

  attr_reader :data, :sensor, :timeframe

  # The year grid on the page of its own in the insights sheet of a phone
  # (the upright variant): a column for each month, a row for each day, the
  # numbers of the days on the left. Each month is 32 cells, its name and 31
  # days. Laid out in columns of 32 from the right, the months run from left
  # to right with the numbers on the left.
  UPRIGHT_GRID =
    'upright:[direction:rtl] upright:*:[direction:ltr] ' \
    'upright:grid-flow-col upright:grid-cols-none upright:auto-cols-fr ' \
    'upright:grid-rows-[auto_repeat(31,minmax(0,1fr))] ' \
    'upright:items-stretch upright:gap-0.5 upright:h-full upright:min-h-100 ' \
    'upright:*:aspect-auto'.freeze
  private_constant :UPRIGHT_GRID

  # The name of a month heads its column. A column is too narrow for a name in
  # a readable size, so only every other month shows its name, and the name
  # reaches into the empty head of its neighbors.
  UPRIGHT_MONTH = 'upright:justify-center upright:p-0 upright:pb-1 upright:text-sm upright:whitespace-nowrap'.freeze
  private_constant :UPRIGHT_MONTH

  # The numbers of the days
  UPRIGHT_DAY = 'upright:flex upright:items-center upright:justify-end upright:m-0 upright:pr-1 upright:text-sm'.freeze
  private_constant :UPRIGHT_DAY

  private

  def years
    timeframe.year? ? [] : data.keys.sort
  end

  # All twelve months, also those still to come or before the first data,
  # so the upright grid on a phone always has the same shape
  def months
    timeframe.year? ? (1..12).to_a : []
  end

  # The wide grid from md on lists the months from the latest down, so a month
  # without data would leave empty rows above the data. There it hides.
  def month_class(month)
    'md:hidden' unless data.key?(month)
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
    sensor_def = Sensor::Registry[sensor_name]

    # Sensors with dynamic colors may return context-dependent classes
    # (e.g. responsive prefixes) that don't apply in heatmap tiles.
    # Use the chart's color_class which provides a plain background.
    if sensor_def.class.meta_data[:color_dynamic]
      chart_instance = sensor_def.chart(timeframe)
      return chart_instance.color_class(sensor_def) if chart_instance
    end

    sensor_def.color_background
  end

  def link_path_for_date(date)
    timeframe = date.respond_to?(:strftime) ? date.strftime('%Y-%m-%d') : date

    helpers.sensor_home_path(sensor.name, timeframe:)
  end
end
