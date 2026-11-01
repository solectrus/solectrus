class Sensor::Data::Base
  # `times` maps a raw sensor name to the timestamp of its latest data point.
  # It is populated for "latest"-style reads (Sensor::Query::Latest) and lets
  # callers reason about per-sensor freshness; it defaults to {} otherwise.
  def initialize(raw_data, timeframe:, times: {})
    @raw_data = raw_data
    @timeframe = timeframe
    @times = times || {}
    # The snapshot timestamp is simply the newest of the per-sensor timestamps,
    # so there is a single source of truth (no separate `time` to keep in sync).
    @time = @times.values.compact.max
    validate!
  end

  attr_reader :timeframe, :raw_data, :time, :times

  # Timestamp of the latest data point for a single raw sensor, or nil.
  def time_for(sensor_name)
    times[sensor_name]
  end

  def single?
    false
  end

  def series?
    false
  end

  def sensor_names
    # simplecov:disable
    raise NotImplementedError
    # simplecov:enable
  end

  # Adds a sensor value (a calculated one -- the stored sensors come in through
  # the constructor). The accessors read the names from raw_data, so the two
  # cannot drift apart.
  def store_sensor_value(sensor_name, value)
    raw_data[sensor_name] = value
    # The name list is derived from raw_data, which may just have gained a key.
    # A new key comes last, as it would on a rebuild of the list. A rebuild at
    # each calculated sensor of each data point costs too much. A new array, as
    # a caller may hold the old one.
    @sensor_names = [*@sensor_names, sensor_name] if @sensor_names&.exclude?(sensor_name)
  end

  # The unit of the sensor parses the raw value (see Sensor::Units)
  def convert_value(raw_value, sensor_name)
    return if raw_value.nil?

    Sensor::Units[Sensor::Registry[sensor_name].unit].parse(raw_value)
  end

  private

  # Each sensor reads as a method of its name, for example `data.house_power`.
  # A series builds one Single per data point, so a method per sensor and
  # object gave each point a class of its own. That was the main cost of a
  # long series.
  def method_missing(name, *args)
    return super if sensor_names.exclude?(name)

    get_sensor_value(name, args)
  end

  def respond_to_missing?(name, include_private = false)
    sensor_names.include?(name) || super
  end

  # Subclasses must implement this method
  def get_sensor_value(sensor_name, args)
    raise NotImplementedError
  end

  def validate!
    return if timeframe.is_a?(Timeframe)

    raise ArgumentError, "timeframe must be a Timeframe, got #{timeframe.class}"
  end
end
