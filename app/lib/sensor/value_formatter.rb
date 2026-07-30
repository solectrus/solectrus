class Sensor::ValueFormatter # rubocop:disable Metrics/ClassLength
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
    @precision = precision || DEFAULT_PRECISION[@unit] || 2
    @context = determine_context(context)
    @scaling = validate_scaling(scaling)
    @sign = sign
  end

  # Money drops its decimals from 10 upwards, and when rounding would leave
  # nothing but zeros ("0" instead of "0,00").
  def self.money_precision(value, precision = DEFAULT_PRECISION[:money])
    rounded = value.round(precision)
    rounded.zero? || rounded.abs >= 10 ? 0 : precision
  end

  # A caller that builds a total out of parts it also displays has to round
  # those parts the way they are shown -- otherwise the numbers on screen stop
  # adding up (43 minus 41 appearing as 1,96). See SplittedCosts::Component.
  def self.round_money(value)
    value.round(money_precision(value))
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

  private

  attr_reader :value,
              :unit,
              :precision,
              :context,
              :scaling,
              :explicit_precision,
              :sign

  # Default precision for each unit type
  DEFAULT_PRECISION = {
    celsius: 1,
    watt: 0,
    gram: 0,
    money: 2,
    money_per_kwh: 4,
    percent: 0,
    unitless: 1,
  }.freeze
  private_constant :DEFAULT_PRECISION

  VALID_SCALING_SYMBOLS = %i[auto off kilo mega].freeze
  private_constant :VALID_SCALING_SYMBOLS

  # ==================== Value Formatting ====================

  def formatted_value
    result =
      case unit
      when :watt, :gram
        format_with_scaling(value)
      when :string
        value.to_s.to_utf8
      when :boolean
        boolean_text(value)
      when :money
        format_money_value(value)
      when nil
        ''
      else
        format_number(value, precision)
      end

    add_sign_prefix(result)
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

  # ==================== Context & Validation ====================

  def determine_context(context)
    return context unless context == :auto

    %i[gram money].include?(unit) ? :total : :rate
  end

  def validate_scaling(scaling)
    return scaling if scaling.is_a?(Numeric)
    return scaling if VALID_SCALING_SYMBOLS.include?(scaling)

    raise ArgumentError,
          "Invalid scaling #{scaling.inspect}. Must be one of: #{VALID_SCALING_SYMBOLS.join(', ')} or a number"
  end

  # ==================== Specific Formatters ====================

  def boolean_text(val)
    val ? I18n.t('general.yes') : I18n.t('general.no')
  end

  def format_with_scaling(val)
    scaled_value = val.to_f / unit_formatter.divisor
    scale_precision = determine_scale_precision_with_override(val)

    # If rounding to the target precision results in zero, use precision 0 instead
    # This ensures "0 kWh" instead of "0,0 kWh" for small values like 0.01 kWh
    scale_precision = 0 if scaled_value.round(scale_precision).zero?

    format_number(scaled_value, scale_precision)
  end

  def determine_scale_precision_with_override(val)
    # Use explicit precision if provided AND the value is scaled
    # For unscaled values (divisor = 1), always use precision 0
    divisor = unit_formatter.divisor
    if explicit_precision && divisor > 1
      explicit_precision
    else
      determine_scale_precision(val)
    end
  end

  def determine_scale_precision(val)
    divisor = unit_formatter.divisor
    return 0 if gram_with_kilo_scale?(divisor)
    return 0 if large_kilowatt_value?(divisor, val)

    precision_for_divisor(divisor)
  end

  def gram_with_kilo_scale?(divisor)
    unit == :gram && divisor == 1_000
  end

  def large_kilowatt_value?(divisor, val)
    unit == :watt && divisor == 1_000 && val.abs >= 100_000
  end

  def precision_for_divisor(divisor)
    case divisor
    when 1
      0
    when 1_000, 1_000_000
      1
    else
      precision
    end
  end

  def format_money_value(val)
    format_number(val, self.class.money_precision(val, precision))
  end

  # ==================== Helper Methods ====================

  def split_formatted_value(formatted)
    separator = I18n.t('number.format.separator', default: ',')
    parts = formatted.split(separator, 2)
    decimal_part = parts.second ? "#{separator}#{parts.second}" : nil
    [parts.first, decimal_part]
  end

  def format_number(num, num_precision)
    ActionController::Base.helpers.number_with_precision(
      num,
      precision: num_precision,
      delimiter: I18n.t('number.format.delimiter'),
      separator: I18n.t('number.format.separator'),
    )
  end
end
