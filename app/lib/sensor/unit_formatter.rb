class Sensor::UnitFormatter
  # Class method for quick formatting
  def self.format(unit:, value: nil, context: :rate, scaling: :auto)
    new(unit:, value:, context:, scaling:).to_s
  end

  # @param unit [Symbol] The unit type from sensor
  # @param value [Numeric, nil] Optional value for auto-scaling (watt, gram)
  # @param context [Symbol] :rate (W, g/h, currency/h) or :total (Wh, g, currency)
  # @param scaling [Symbol, Numeric] :auto, :off, :kilo, :mega, or explicit number
  def initialize(unit:, value: nil, context: :rate, scaling: :auto)
    @definition = Sensor::Units[unit]
    @value = value
    @context = context
    @scaling = scaling
  end

  # Returns the unit string
  def to_s
    definition.label(prefix:, context:)
  end

  # Returns the scale divisor (1, 1000, 1_000_000)
  def divisor
    scale[:divisor]
  end

  # Returns the scale prefix (k, M)
  def prefix
    scale[:prefix]
  end

  private

  attr_reader :definition, :value, :context, :scaling

  NO_SCALE = { divisor: 1, prefix: '' }.freeze
  private_constant :NO_SCALE

  def scale
    @scale ||= determine_scale
  end

  def determine_scale
    return NO_SCALE unless definition.scalable?

    magnitude = scale_magnitude
    magnitude ? step_for(magnitude) : NO_SCALE
  end

  # The size the scale step is picked by: the value itself when auto-scaling,
  # otherwise the size the caller named. Nothing (:off, nil, or anything
  # unknown) means: leave it unscaled.
  def scale_magnitude
    case scaling
    when :auto
      value&.abs
    when :kilo
      1_000
    when :mega
      1_000_000
    when Numeric
      scaling.abs
    end
  end

  # The smallest step the value stays below -- 999 W stay watts, 1 kW and up
  # become kilowatts. Each step's threshold is the next step's divisor, so
  # naming a divisor (:kilo, :mega) picks the same step as a value of that size.
  def step_for(abs_value)
    definition.scale_steps.find { |step| abs_value < step[:threshold] } ||
      NO_SCALE
  end
end
