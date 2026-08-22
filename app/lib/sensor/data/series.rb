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

  # The instants `points` sits on, in the same order - point i was built for
  # timestamps[i].
  #
  # Published because a point cannot answer for itself: Single carries only a
  # day-granular Timeframe, not the instant it was built for. Anything pairing
  # points back with times had to rebuild this list from raw_data and trust
  # that it came out identical. It did, but the two derivations sat in
  # different files, and a change to either would have shifted every
  # calculated value onto a neighbouring timestamp - silently, since both
  # lists stay the same LENGTH.
  attr_reader :points, :timestamps

  def sensor_names
    @sensor_names ||=
      begin
        result = raw_data.keys.map(&:first)
        result.uniq!
        result
      end
  end

  # One list of sensor names per point, in the order of #points.
  #
  # A sensor counts as reporting from its first value to its last, so a nil
  # BETWEEN those two still names it. That is the point: such a nil is a gap
  # in a sensor that is there, and only a gap can leave a derived value
  # unknown (see Sensor::Definitions::InverterPowerTotal). A nil before the
  # first value or after the last names nothing, because the sensor was not
  # there yet, or is gone.
  #
  # A key cannot draw that line. SQL answers with a column for every stored
  # field it was asked for, NULLs included, so an inverter added halfway
  # through the month looks present on every day of it.
  def reporting_sensor_names
    coverage = sensor_coverage

    Array.new(points.size) do |index|
      coverage.filter_map { |name, range| name if range.cover?(index) }
    end
  end

  def series?
    true
  end

  # The raw {time => value} hash for a sensor, irrespective of its aggregation
  # combination. Returns nil when the sensor carries no data. Handy when the
  # caller knows the sensor but not its aggregation key (e.g. forecast curves).
  def raw_for(sensor_name)
    raw_data.find { |key, _| key.first == sensor_name }&.last
  end

  private

  # The range of point indices each sensor delivers over. Grouped by sensor
  # first, because a SQL result carries one key per aggregation and the range
  # is the sensor's, not one key's.
  def sensor_coverage
    index_of = timestamps.each_with_index.to_h

    raw_data
      .group_by { |key, _| key.first }
      .filter_map do |name, entries|
        indices = value_indices(entries, index_of)
        next if indices.empty?

        first, last = indices.minmax
        [name, first..last]
      end
      .to_h
  end

  def value_indices(entries, index_of)
    entries.flat_map do |_, time_series|
      time_series.filter_map { |time, value| index_of[time] unless value.nil? }
    end
  end

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
    @timestamps = []
    return [] if raw_data.empty?

    # The union across sensors, not one sensor's keys: sensors may sit on
    # different grids (forecast at bucket midpoints, live data at right
    # edges), so taking the first sensor's would drop the others' instants.
    all_timestamps = raw_data.values.flat_map(&:keys).uniq
    all_timestamps.sort!
    @timestamps = all_timestamps

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
