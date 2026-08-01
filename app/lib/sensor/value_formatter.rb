class Sensor::ValueFormatter
  def initialize(
    value,
    unit:,
    precision: nil,
    context: :auto,
    scaling: :auto,
    sign: false
  )
    @value = value
    @unit = unit
    @explicit_precision = precision
    @context = context == :auto ? definition.default_context : context
    @scaling = validate_scaling(scaling)
    @sign = sign
  end

  # A caller that builds a total out of parts it also displays has to round
  # those parts the way they are shown -- otherwise the numbers on screen stop
  # adding up (43 minus 41 appearing as 1,96). See SplittedCosts::Component.
  def self.round_money(value)
    value.round(new(value, unit: :money).precision)
  end

  def to_h
    return {} if value.nil?

    formatted = formatted_value

    integer_part, decimal_part =
      (formatted.is_a?(String) ? split_formatted_value(formatted) : [nil, nil])

    {
      value: formatted,
      integer: integer_part,
      decimal: decimal_part,
      unit: unit_string,
    }
  end

  def to_s
    return '' if value.nil?

    [formatted_value, unit_string].compact.join(' ')
  end

  # Decimals the value is printed with: what its unit asks for, unless the
  # caller knows better -- or rounding would leave nothing but zeros
  # ("0 kWh", not "0,0 kWh").
  def precision
    @precision ||=
      if displayed_value.is_a?(Numeric)
        wanted = requested_precision
        displayed_value.round(wanted).zero? ? 0 : wanted
      else
        0
      end
  end

  private

  attr_reader :value, :unit, :context, :scaling, :explicit_precision, :sign

  VALID_SCALING_SYMBOLS = %i[auto off kilo mega].freeze
  private_constant :VALID_SCALING_SYMBOLS

  def definition
    @definition ||= Sensor::Units[unit]
  end

  # ==================== Value Formatting ====================

  def formatted_value
    add_sign_prefix(definition.format(displayed_value, precision:))
  end

  # The number that actually gets printed: watt and gram are shown scaled
  # (kWh, kg), every other unit as it is.
  def displayed_value
    @displayed_value ||=
      definition.scalable? ? value.to_f / divisor : value
  end

  # Only scalable units ever divide, so the others need no formatter to answer
  def divisor
    definition.scalable? ? unit_formatter.divisor : 1
  end

  def add_sign_prefix(result)
    return result unless sign && value && result.present?

    prefix = value.positive? ? '+' : ''
    "#{prefix}#{result}"
  end

  # ==================== Unit Formatting ====================

  def unit_string
    result = unit_formatter.to_s
    result.presence
  end

  def unit_formatter
    @unit_formatter ||=
      Sensor::UnitFormatter.new(unit:, value: value || 0, context:, scaling:)
  end

  # ==================== Precision ====================

  def requested_precision
    return explicit_precision if explicit_precision && !raw_scale?

    definition.precision(displayed_value, divisor:)
  end

  # A caller's precision refers to the number as printed ("three decimals of
  # a kWh"). A scalable unit at base scale (raw watt-hours, raw grams) is
  # whole numbers to begin with, so there is nothing left to refine.
  def raw_scale?
    definition.scalable? && divisor == 1
  end

  # ==================== Validation ====================

  def validate_scaling(scaling)
    return scaling if scaling.is_a?(Numeric)
    return scaling if VALID_SCALING_SYMBOLS.include?(scaling)

    raise ArgumentError,
          "Invalid scaling #{scaling.inspect}. Must be one of: #{VALID_SCALING_SYMBOLS.join(', ')} or a number"
  end

  # ==================== Helper Methods ====================

  def split_formatted_value(formatted)
    separator = I18n.t('number.format.separator', default: ',')
    parts = formatted.split(separator, 2)
    decimal_part = parts.second ? "#{separator}#{parts.second}" : nil
    [parts.first, decimal_part]
  end
end
