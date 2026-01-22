class SensorValue::Component < ViewComponent::Base
  def initialize(data_or_value, sensor_name, **options)
    super()
    @sensor = Sensor::Registry[sensor_name]
    @raw_value = extract_value(data_or_value)
    @options = options

    validate_sign_option!
  end

  ALLOWED_SIGNS = %i[
    positive
    negative
    neutral
    value_based
    value_based_reverse
  ].freeze
  private_constant :ALLOWED_SIGNS

  attr_reader :raw_value, :sensor, :options

  def missing?
    raw_value.nil?
  end

  def title(format = :long)
    sensor.display_name(format)
  end

  def unit
    @unit ||= formatted_data[:unit]
  end

  def css_classes
    classes = ['sensor-value']
    classes << "sensor-#{sensor.name.to_s.dasherize}"

    # Add red/green color based on sign option
    case sign
    when :positive
      classes << 'text-emerald-700 dark:text-emerald-500'
    when :negative
      classes << 'text-red-700 dark:text-red-500'
    when :neutral
      # No color added
    end

    classes << options[:class] if options[:class]
    classes.join(' ')
  end

  def integer_part
    return '' if value.blank?

    value.split(separator).first || ''
  end

  def decimal_part
    return unless value

    parts = value.split(separator)
    parts.second if parts.length > 1
  end

  def separator
    I18n.t('number.format.separator')
  end

  private

  def sign
    if %i[value_based value_based_reverse].exclude?(options[:sign])
      return options[:sign]
    end
    return if raw_value.nil?

    reverse = options[:sign] == :value_based_reverse
    calculate_sign_from_value(reverse)
  end

  def calculate_sign_from_value(reverse)
    result =
      if raw_value.positive?
        :positive
      elsif raw_value.negative?
        :negative
      else
        :neutral
      end

    reverse ? invert_sign(result) : result
  end

  def invert_sign(sign)
    case sign
    when :positive
      :negative
    when :negative
      :positive
    else
      :neutral
    end
  end

  def validate_sign_option!
    return if options[:sign].nil? || ALLOWED_SIGNS.include?(options[:sign])

    raise ArgumentError,
          "Invalid sign option: #{options[:sign].inspect}. " \
            "Allowed values: #{ALLOWED_SIGNS.join(', ')}"
  end

  def value
    @value ||= formatted_data[:value]
  end

  def formatted_data
    @formatted_data ||=
      Sensor::ValueFormatter.new(
        value_for_formatting,
        unit: sensor.unit,
        **formatter_options,
      ).to_h
  end

  def value_for_formatting
    if options[:sign].present? && raw_value.respond_to?(:abs)
      raw_value.abs
    else
      raw_value
    end
  end

  def formatter_options
    options.except(:class, :sign)
  end

  # Extract value from either a Data object or a direct value
  def extract_value(data_or_value)
    if data_or_value.respond_to?(sensor.name)
      # It's a Data object - extract the sensor value
      data_or_value.public_send(sensor.name)
    else
      # It's a direct value - use as-is
      data_or_value
    end
  end
end
