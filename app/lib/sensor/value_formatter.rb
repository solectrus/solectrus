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
    @precision = precision || DEFAULT_PRECISION[@unit] || 2
    @context = determine_context(context)
    @scaling = validate_scaling(scaling)
    @sign = sign
  end

  def to_h
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
    euro: 2,
    euro_per_kwh: 4,
    percent: 0,
  }.freeze
  private_constant :DEFAULT_PRECISION

  VALID_SCALING_SYMBOLS = %i[auto off kilo mega].freeze
  private_constant :VALID_SCALING_SYMBOLS

  # ==================== Value Formatting ====================

  def formatted_value
    return '' if value.nil?

    result =
      case unit
      when :watt, :gram
        format_with_scaling
      when :string
        value.to_s
      when :boolean
        boolean_text
      when :euro
        format_euro_value
      when nil
        ''
      else
        format_number(value, precision)
      end

    add_sign_prefix(result)
  end

  def add_sign_prefix(result)
    return result unless sign
    return result if value.nil? || result.blank?

    prefix = value.positive? ? '+' : ''
    "#{prefix}#{result}"
  end

  # ==================== Unit Formatting ====================

  def unit_string
    result = unit_formatter.to_s
    result.empty? ? nil : result
  end

  def unit_formatter
    @unit_formatter ||=
      Sensor::UnitFormatter.new(unit:, value:, context:, scaling:)
  end

  # ==================== Context & Validation ====================

  def determine_context(context)
    return context unless context == :auto

    # Gram uses :total context to show "g" (total) instead of "g/h" (rate)
    # All other units use :rate context
    unit == :gram ? :total : :rate
  end

  def validate_scaling(scaling)
    return scaling if scaling.is_a?(Numeric)
    return scaling if VALID_SCALING_SYMBOLS.include?(scaling)

    raise ArgumentError,
          "Invalid scaling #{scaling.inspect}. Must be one of: #{VALID_SCALING_SYMBOLS.join(', ')} or a number"
  end

  # ==================== Specific Formatters ====================

  def boolean_text
    value ? I18n.t('general.yes') : I18n.t('general.no')
  end

  def format_with_scaling
    scaled_value = value.to_f / unit_formatter.divisor
    scale_precision = explicit_precision || determine_scale_precision

    # If rounding to the target precision results in zero, use precision 0 instead
    # This ensures "0 kWh" instead of "0,0 kWh" for small values like 0.01 kWh
    scale_precision = 0 if scaled_value.round(scale_precision).zero?

    format_number(scaled_value, scale_precision)
  end

  def determine_scale_precision
    return 0 if gram_kilo?
    return 0 if large_kilowatt?

    # Standard-Precision basierend auf Scale
    case unit_formatter.divisor
    when 1
      0
    when 1_000, 1_000_000
      1
    else
      precision
    end
  end

  def gram_kilo?
    unit == :gram && unit_formatter.divisor == 1_000
  end

  def large_kilowatt?
    unit == :watt && unit_formatter.divisor == 1_000 && value.abs >= 100_000
  end

  def format_euro_value
    return '' if value.nil?

    euro_precision = euro_precision_for_value
    format_number(value, euro_precision)
  end

  def euro_precision_for_value
    # Large amounts (>= 10 EUR) without decimals, small amounts with decimals
    value.abs >= 10 ? 0 : precision
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
