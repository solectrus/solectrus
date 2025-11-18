# Sensor::Data::Single represents sensor data at a single point in time.
#
# Usage examples:
#
# 1. Current sensor values:
#   data = Sensor::Data::Single.new({house_power: 1500}, timeframe: Timeframe.now)
#   data.house_power  # => 1500.0
#
# 2. Daily aggregated values:
#   data = Sensor::Data::Single.new({[:house_power, :sum] => 15000}, timeframe: Timeframe.day)
#   data.house_power(:sum)  # => 15000.0
#   data.house_power        # => 15000.0 (defaults to :sum)
#
# 3. Meta-aggregated values (e.g., average of daily sums):
#   data = Sensor::Data::Single.new({[:house_power, :avg, :sum] => 12500}, timeframe: Timeframe.month)
#   data.house_power(:avg, :sum)  # => 12500.0
#
class Sensor::Data::Single < Sensor::Data::Base
  def sensor_names
    @sensor_names ||=
      raw_data.keys.filter_map { |key| extract_sensor_name(key) }.uniq
  end

  def single?
    true
  end

  private

  def extract_sensor_name(key)
    case key
    when Symbol
      key
    when Array
      key.first
    else
      raise ArgumentError, "Invalid key: #{key}"
    end
  end

  def get_sensor_value(sensor_name, args)
    case args.length
    when 0
      get_default_value(sensor_name)
    when 1, 2
      get_aggregated_value(sensor_name, args)
    else
      raise ArgumentError,
            "Expected 0, 1 or 2 aggregation parameters, got #{args.length}"
    end
  end

  def get_default_value(sensor_name)
    # Direct sensor value (no aggregation)
    if raw_data.key?(sensor_name)
      return convert_value(raw_data[sensor_name], sensor_name)
    end

    # Find all aggregation keys for this sensor
    sensor_keys =
      raw_data.keys.select { |k| k.is_a?(Array) && k.first == sensor_name }

    case sensor_keys.length
    when 0
      nil
    when 1
      # Exactly one aggregation - use it
      convert_value(raw_data[sensor_keys.first], sensor_name)
    else
      # Multiple aggregations - require explicit parameters
      raise ArgumentError,
            "Sensor '#{sensor_name}' has multiple aggregations. Use explicit aggregation parameters."
    end
  end

  def get_aggregated_value(sensor_name, aggregations)
    key = [sensor_name, *aggregations]
    unless raw_data.key?(key)
      error_msg =
        if aggregations.length == 1
          "No data found for sensor '#{sensor_name}' with aggregation '#{aggregations.first}'"
        else
          "No data found for sensor '#{sensor_name}' with meta-aggregation '#{aggregations.first}' and aggregation '#{aggregations.last}'"
        end
      raise ArgumentError, error_msg
    end

    convert_value(raw_data[key], sensor_name)
  end

  def validate!
    super
    unless raw_data.is_a?(Hash)
      raise ArgumentError, 'Single data must be a Hash'
    end

    raw_data.each_key do |key|
      case key
      when Symbol
        # Direct sensor key - OK
      when Array
        validate_array_key(key)
      else
        raise ArgumentError, "Invalid key format: #{key}"
      end
    end
  end

  def validate_array_key(key)
    unless key.length.between?(2, 3)
      raise ArgumentError,
            "Array key must have 2 or 3 elements, got #{key.length}"
    end

    key.each_with_index do |element, index|
      if index.zero?
        unless element.is_a?(Symbol)
          raise ArgumentError,
                "Sensor name must be a Symbol, got #{element.class}: #{element.inspect}"
        end
      else
        unless element.is_a?(Symbol) && %i[sum avg min max].include?(element)
          raise ArgumentError, "Invalid aggregation: #{element.inspect}"
        end
      end
    end
  end
end
