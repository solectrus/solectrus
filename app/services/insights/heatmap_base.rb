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
    # :nocov:
    raise NotImplementedError
    # :nocov:
  end

  # Abstract method - must be implemented by subclasses
  def build_data
    # :nocov:
    raise NotImplementedError
    # :nocov:
  end

  # Abstract method - subclasses define their grouping dimensions
  def grouping_expressions
    # :nocov:
    raise NotImplementedError
    # :nocov:
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
  def fetch_inverter_power_data
    # Check if inverter_power has direct summary data
    if base_scope.exists?(field: :inverter_power)
      return fetch_standard_data(:inverter_power)
    end

    # Otherwise aggregate all inverter_power_X fields
    inverter_fields =
      SummaryValue.fields.keys.filter_map do |field|
        field.to_sym if field.to_s.match?(/^inverter_power_\d+$/)
      end

    return [] if inverter_fields.empty?

    base_scope
      .where(field: inverter_fields)
      .sum(:value)
      .map { |key, total_value| format_data_entry(key, total_value) }
  end

  def fetch_grid_power_data
    query_result =
      Sensor::Query::Sql
        .new do |q|
          q.sum :grid_revenue
          q.sum :grid_costs
          q.sum :grid_balance

          q.timeframe timeframe
          q.group_by(timeframe.year? ? :day : :month)
        end
        .call

    # Convert to heatmap format
    revenue_data = query_result.grid_revenue(:sum, :sum)
    costs_data = query_result.grid_costs(:sum, :sum)
    balance_data = query_result.grid_balance(:sum, :sum)

    revenue_data.keys.map do |date_key|
      date_parts =
        if timeframe.year?
          [date_key.month, date_key.day]
        else
          [date_key.year, date_key.month]
        end

      format_data_entry(
        date_parts,
        {
          grid_revenue: revenue_data[date_key] || 0,
          grid_costs: costs_data[date_key] || 0,
          grid_balance: balance_data[date_key] || 0,
        },
      )
    end
  end

  def fetch_standard_data(field = sensor.name)
    base_scope
      .where(field:)
      .sum(:value)
      .map { |key, value| format_data_entry(key, value) }
  end

  def fetch_calculated_data
    # For calculated sensors (like finance sensors), use Sensor::Query::Sql
    aggregation = sensor.allowed_aggregations.first || :sum

    query_result =
      Sensor::Query::Sql
        .new do |q|
          q.public_send(aggregation, sensor.name)

          q.timeframe timeframe
          q.group_by(timeframe.year? ? :day : :month)
        end
        .call

    # Convert to heatmap format
    # For avg aggregation, use avg for both meta and base aggregation
    base_agg = aggregation == :avg ? :avg : :sum
    data = query_result.public_send(sensor.name, aggregation, base_agg)

    data.keys.map do |date_key|
      date_parts =
        if timeframe.year?
          [date_key.month, date_key.day]
        else
          [date_key.year, date_key.month]
        end

      format_data_entry(date_parts, data[date_key] || 0)
    end
  end

  def fetch_data
    return [] unless sensor

    case sensor.name
    when :inverter_power
      fetch_inverter_power_data
    when :grid_power
      fetch_grid_power_data
    when :battery_power
      fetch_standard_data(:battery_discharging_power)
    else
      fetch_sensor_data
    end
  end

  def fetch_sensor_data
    if calculated_sensor?
      fetch_calculated_data
    else
      fetch_standard_data
    end
  end

  def calculated_sensor?
    (sensor.sql_calculated? || sensor.calculated?) && !sensor.store_in_summary?
  end

  # Abstract method - subclasses define their date dimensions
  def date_dimensions
    # :nocov:
    raise NotImplementedError
    # :nocov:
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
end
