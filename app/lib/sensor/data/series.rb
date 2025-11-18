# Sensor::Data::Series represents sensor data over time periods with meta-aggregations.
#
# Usage example:
#   data = Sensor::Data::Series.new({
#     [:house_power, :sum, :sum] => {
#       Date.new(2025, 1, 1) => 3750.0,
#       Date.new(2025, 2, 1) => 3400.0,
#       Date.new(2025, 3, 1) => 3200.0
#     },
#     [:case_temp, :avg, :min] => {
#       Date.new(2025, 1, 1) => 20.0,
#       Date.new(2025, 2, 1) => 24.0,
#       Date.new(2025, 3, 1) => 25.0
#     }
#   }, timeframe: Timeframe.new("2025"))
#
#   data.house_power(:sum, :sum)  # => Hash with Date => Float mappings
#   data.case_temp(:avg, :min)    # => Hash with Date => Float mappings
#
class Sensor::Data::Series < Sensor::Data::Base
  def initialize(raw_data, timeframe:)
    unless raw_data.is_a?(Hash)
      raise ArgumentError, 'Series data must be a Hash with sensor keys'
    end

    # Validate before building points
    validate_series_data!(raw_data)

    @points = build_points(raw_data, timeframe)
    super
  end

  attr_reader :points

  def sensor_names
    @sensor_names ||=
      begin
        result = raw_data.keys.map(&:first)
        result.uniq!
        result
      end
  end

  def series?
    true
  end

  private

  def get_sensor_value(sensor_name, args)
    return get_aggregated_sensor_data(sensor_name, args) unless args.empty?

    raise_parameter_error(sensor_name)
  end

  def get_aggregated_sensor_data(sensor_name, args)
    raise_parameter_error(sensor_name) unless args.length == 2

    # Find matching key and return time series data
    key = [sensor_name, *args]
    raise_parameter_error(sensor_name) unless raw_data.key?(key)

    # Convert values and return as Hash
    raw_data[key].transform_values { |value| convert_value(value, sensor_name) }
  end

  def raise_parameter_error(sensor_name)
    available_combinations = find_available_combinations(sensor_name)
    examples =
      available_combinations.map do |combo|
        "#{sensor_name}(#{combo.map(&:inspect).join(', ')})"
      end
    raise ArgumentError,
          "Series data requires exactly 2 aggregation parameters. Available: #{examples.join(', ')}"
  end

  def build_points(raw_data, _timeframe)
    return [] if raw_data.empty?

    # Collect all timestamps
    all_timestamps = raw_data.values.flat_map(&:keys).uniq
    all_timestamps.sort!

    # Create Single data objects for each timestamp
    all_timestamps.map do |timestamp|
      point_data = {}
      raw_data.each do |sensor_key, time_series|
        sensor_name = sensor_key.first
        point_data[sensor_name] = time_series[timestamp] if time_series.key?(
          timestamp,
        )
      end

      Sensor::Data::Single.new(
        point_data,
        timeframe: Timeframe.new(timestamp.strftime('%Y-%m-%d')),
      )
    end
  end

  def validate_series_data!(raw_data)
    raw_data.each do |key, time_data|
      validate_series_key!(key)
      validate_time_data!(time_data)
    end
  end

  def validate_series_key!(key)
    unless key.is_a?(Array)
      raise ArgumentError,
            "Invalid series key format: #{key.inspect}. Must be Array"
    end

    unless key.length == 3
      raise ArgumentError,
            "Series key must be Array with 3 elements, got #{key.length}: #{key.inspect}"
    end

    validate_key_elements!(key)
  end

  def validate_key_elements!(key)
    key.each_with_index do |element, index|
      if index.zero?
        validate_sensor_name!(element)
      else
        validate_aggregation!(element)
      end
    end
  end

  def validate_sensor_name!(element)
    return if element.is_a?(Symbol)

    raise ArgumentError,
          "Sensor name must be a Symbol, got #{element.class}: #{element.inspect}"
  end

  def validate_aggregation!(element)
    return if element.is_a?(Symbol) && %i[sum avg min max].include?(element)

    raise ArgumentError, "Invalid aggregation: #{element.inspect}"
  end

  def validate_time_data!(time_data)
    unless time_data.is_a?(Hash)
      raise ArgumentError, "Time data must be a Hash, got #{time_data.class}"
    end

    time_data.each_key do |time_key|
      unless time_key.is_a?(Date) || time_key.is_a?(Time)
        raise ArgumentError,
              "Time keys must be Date or Time objects, got #{time_key.class}: #{time_key.inspect}"
      end
    end
  end

  def find_available_combinations(sensor_name)
    raw_data
      .keys
      .filter_map do |key|
        unless key.is_a?(Array) && key.first == sensor_name && key.length == 3
          next
        end

        key[1, 2] # Extract meta-aggregation and aggregation parts
      end
      .uniq
  end
end
