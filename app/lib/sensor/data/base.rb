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
    define_sensor_accessors
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
  # the constructor) and publishes its accessor in the same step, so raw_data
  # and the accessors cannot drift apart.
  def store_sensor_value(sensor_name, value)
    raw_data[sensor_name] = value
    publish_sensor(sensor_name)
  end

  def convert_value(raw_value, sensor_name)
    return if raw_value.nil?

    sensor = Sensor::Registry[sensor_name]
    case sensor.unit
    when :watt, :celsius, :unitless, :percent, :gram, :money, :money_per_kwh
      to_float(raw_value)
    when :boolean
      to_boolean(raw_value)
    when :string
      to_string(raw_value)
    else
      raise ArgumentError, "Unknown unit type: #{sensor.unit}"
    end
  end

  private

  # Uniform sensor accessor creation for all subclasses
  def define_sensor_accessors
    # Clear cached sensor names to ensure we get the current state
    @sensor_names = nil
    sensor_names.each { |sensor_name| publish_sensor(sensor_name) }
  end

  # Makes a single sensor readable. Publishing one new sensor by redefining every
  # accessor is what dominated the cost of a chart series, where this happens per
  # data point and calculated sensor.
  def publish_sensor(sensor_name)
    # The name list is derived from raw_data, which may just have gained a key
    @sensor_names = nil

    define_singleton_method(sensor_name) do |*args|
      get_sensor_value(sensor_name, args)
    end
  end

  # Subclasses must implement this method
  def get_sensor_value(sensor_name, args)
    raise NotImplementedError
  end

  def validate!
    return if timeframe.is_a?(Timeframe)

    raise ArgumentError, "timeframe must be a Timeframe, got #{timeframe.class}"
  end

  def to_boolean(raw_value)
    case raw_value
    when TrueClass, FalseClass
      raw_value
    when 1, '1', 'true', 'on', 'yes'
      true
    when 0, '0', 'false', 'off', 'no', ''
      false
    else
      !raw_value.nil?
    end
  end

  def to_float(raw_value)
    raw_value.to_f
  end

  def to_string(raw_value)
    raw_value.to_s
  end
end
