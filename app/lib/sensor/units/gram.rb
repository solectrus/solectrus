class Sensor::Units::Gram < Sensor::Units::Base
  SCALE_STEPS = [
    { threshold: 1_000, divisor: 1, prefix: '' },
    { threshold: 1_000_000, divisor: 1_000, prefix: 'k' },
    { threshold: Float::INFINITY, divisor: 1_000_000, prefix: 't' },
  ].freeze
  private_constant :SCALE_STEPS

  def scale_steps
    SCALE_STEPS
  end

  def default_context
    :total
  end

  def label(prefix: '', context: :rate)
    # Tonnes are just 't', not 'tg'
    return 't' if prefix == 't'

    "#{prefix}#{context == :total ? 'g' : 'g/h'}"
  end

  # Grams and kilograms are read as whole numbers
  def precision(printed_value, divisor: 1)
    return 0 if divisor <= 1_000

    decimal_while_short(printed_value)
  end

  # Three decimals of a kg are grams again
  def exact_precision
    3
  end
end
