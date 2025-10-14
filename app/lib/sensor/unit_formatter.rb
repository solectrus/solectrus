class Sensor::UnitFormatter
  # Class method for quick formatting
  def self.format(unit:, value: nil, context: :rate, scaling: :auto, html: true)
    new(unit:, value:, context:, scaling:).public_send(html ? :to_html : :to_s)
  end

  # @param unit [Symbol] The unit type from sensor
  # @param value [Numeric, nil] Optional value for auto-scaling (watt, gram)
  # @param context [Symbol] :rate (W, g/h) or :total (Wh, g, EUR)
  # @param scaling [Symbol, Numeric] :auto, :off, :kilo, :mega, or explicit number
  def initialize(unit:, value: nil, context: :rate, scaling: :auto)
    @unit = unit
    @value = value
    @context = context
    @scaling = scaling
  end

  # Returns the unit string with HTML entities
  def to_html
    unit_string(html: true)
  end

  # Returns the unit string as plain text (for display)
  def to_s
    unit_string(html: false)
  end

  # Returns the scale divisor (1, 1000, 1_000_000)
  def divisor
    return 1 if scaling == :off || !scalable_unit?

    scale_config[:divisor]
  end

  # Returns the scale prefix (k, M)
  def prefix
    return '' if scaling == :off || !scalable_unit?

    scale_config[:prefix]
  end

  private

  attr_reader :unit, :value, :context, :scaling

  WATT_SCALING = [
    { threshold: 1_000, scale: :base, divisor: 1, prefix: '' },
    { threshold: 1_000_000, scale: :kilo, divisor: 1_000, prefix: 'k' },
    {
      threshold: Float::INFINITY,
      scale: :mega,
      divisor: 1_000_000,
      prefix: 'M',
    },
  ].freeze
  private_constant :WATT_SCALING

  GRAM_SCALING = [
    { threshold: 1_000, scale: :base, divisor: 1, prefix: '' },
    { threshold: 1_000_000, scale: :kilo, divisor: 1_000, prefix: 'k' },
    {
      threshold: Float::INFINITY,
      scale: :mega,
      divisor: 1_000_000,
      prefix: 't',
    },
  ].freeze
  private_constant :GRAM_SCALING

  def unit_string(html:) # rubocop:disable Metrics/CyclomaticComplexity
    case unit
    when :watt, :gram
      scaled_unit
    when :celsius
      html ? '&deg;C'.html_safe : '°C'
    when :percent
      html ? '&percnt;'.html_safe : '%'
    when :euro
      html ? '&euro;'.html_safe : '€'
    when :euro_per_kwh
      html ? '&euro;/kWh'.html_safe : '€/kWh'
    when :unitless, :boolean, :string
      ''
    end
  end

  def scalable_unit?
    %i[watt gram].include?(unit)
  end

  def scaled_unit
    # Special case: tonne is just 't', not 'tg'
    return 't' if unit == :gram && prefix == 't'

    base = base_unit_string
    "#{prefix}#{base}"
  end

  def base_unit_string
    case unit
    when :watt
      context == :total ? 'Wh' : 'W'
    when :gram
      context == :total ? 'g' : 'g/h'
    end
  end

  def scale_config
    @scale_config ||=
      case scaling
      when :auto
        determine_auto_scale
      when :kilo
        kilo_scale
      when :mega
        mega_scale
      when Numeric
        determine_scale_for_value(scaling.abs)
      else
        no_scale # :off, nil, or unknown
      end
  end

  def no_scale
    { divisor: 1, prefix: '' }
  end

  def kilo_scale
    { divisor: 1_000, prefix: 'k' }
  end

  def mega_scale
    if unit == :gram
      { divisor: 1_000_000, prefix: 't' }
    else
      { divisor: 1_000_000, prefix: 'M' }
    end
  end

  def determine_auto_scale
    return no_scale if value.nil?

    determine_scale_for_value(value.abs)
  end

  def determine_scale_for_value(abs_value)
    table = unit == :gram ? GRAM_SCALING : WATT_SCALING
    config = table.find { |s| abs_value < s[:threshold] }
    { divisor: config[:divisor], prefix: config[:prefix] }
  end
end
