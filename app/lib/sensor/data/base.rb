class Sensor::Data::Base
  def initialize(raw_data, timeframe:, time: nil)
    @raw_data = raw_data
    @timeframe = timeframe
    @time = time
    validate!
    define_sensor_accessors
  end

  attr_reader :timeframe, :raw_data, :time

  def single?
    false
  end

  def series?
    false
  end

  def sensor_names
    # :nocov:
    raise NotImplementedError
    # :nocov:
  end

  # Uniform sensor accessor creation for all subclasses
  def define_sensor_accessors
    # Clear cached sensor names to ensure we get the current state
    @sensor_names = nil
    sensor_names.each do |sensor_name|
      define_singleton_method(sensor_name) do |*args|
        get_sensor_value(sensor_name, args)
      end
    end
  end

  def convert_value(raw_value, sensor_name)
    return if raw_value.nil?

    sensor = Sensor::Registry[sensor_name]
    case sensor.unit
    when :watt, :celsius, :unitless, :percent, :gram, :euro, :euro_per_kwh
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
