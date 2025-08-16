class Insights::HeatmapBase
  def initialize(sensor:, timeframe:)
    @sensor = sensor
    @timeframe = timeframe
  end

  attr_reader :sensor, :timeframe

  def call
    return unless valid_timeframe?

    build_data
  end

  private

  # Abstract method - must be implemented by subclasses
  def valid_timeframe?
    raise NotImplementedError
  end

  # Abstract method - must be implemented by subclasses
  def build_data
    raise NotImplementedError
  end

  # Abstract method - subclasses define their grouping dimensions
  def grouping_expressions
    raise NotImplementedError
  end

  # Generic base_scope implementation
  def base_scope
    SummaryValue
      .where(aggregation: :sum)
      .where(
        date:
          timeframe.effective_beginning_date..timeframe.effective_ending_date,
      )
      .group(*grouping_expressions)
  end

  # Shared data fetching methods
  def fetch_house_power_data
    excluded_sensors = SensorConfig.x.excluded_sensor_names
    return fetch_standard_data if excluded_sensors.empty?

    house_power_data = base_scope.where(field: :house_power).sum(:value)
    excluded_power_data = base_scope.where(field: excluded_sensors).sum(:value)

    house_power_data.map do |key, house_value|
      excluded_value = excluded_power_data[key] || 0
      adjusted_value = house_value - excluded_value
      format_data_entry(key, adjusted_value)
    end
  end

  def fetch_inverter_power_data
    return fetch_standard_data if SensorConfig.x.inverter_total_present?

    inverter_sensors = SensorConfig.x.existing_custom_inverter_sensor_names
    return fetch_standard_data if inverter_sensors.empty?

    base_scope
      .where(field: inverter_sensors)
      .sum(:value)
      .map { |key, total_value| format_data_entry(key, total_value) }
  end

  def fetch_grid_power_data
    raw_data =
      base_scope
        .where(field: %i[grid_revenue grid_costs])
        .group(:field)
        .sum(:value)

    grouped_data =
      raw_data.each_with_object({}) do |(key, value), result|
        date_key = extract_date_key(key)
        field_key = extract_field_key(key)

        result[date_key] ||= { grid_revenue: 0, grid_costs: 0 }
        result[date_key][field_key] = value
      end

    grouped_data.map do |date_key, field_values|
      format_data_entry(date_key, field_values)
    end
  end

  def fetch_standard_data(field = sensor)
    base_scope
      .where(field:)
      .sum(:value)
      .map { |key, value| format_data_entry(key, value) }
  end

  def fetch_data
    case sensor
    when :house_power
      fetch_house_power_data
    when :inverter_power
      fetch_inverter_power_data
    when :grid_power
      fetch_grid_power_data
    when :battery_power
      fetch_standard_data(:battery_discharging_power)
    else
      fetch_standard_data
    end
  end

  # Abstract method - subclasses define their date dimensions
  def date_dimensions
    raise NotImplementedError
  end

  # Generic data processing based on dimensions
  def format_data_entry(key, value)
    result = {}
    date_dimensions.each_with_index do |dim, index|
      result[dim] = key[index].to_i
    end
    result[:value] = value
    result
  end

  def extract_date_key(key)
    if key.is_a?(Array) && key.length >= date_dimensions.length
      result = key.first(date_dimensions.length)
      result.map!(&:to_i)
      result
    else
      date_dimensions.map { |dim| key[dim] }
    end
  end

  def extract_field_key(key)
    if key.is_a?(Array) && key.length > date_dimensions.length
      key[date_dimensions.length].to_sym
    else
      key[:field]
    end
  end
end
