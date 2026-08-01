class Sensor::Units::Watt < Sensor::Units::Base
  SCALE_STEPS = [
    { threshold: 1_000, divisor: 1, prefix: '' },
    { threshold: 1_000_000, divisor: 1_000, prefix: 'k' },
    { threshold: Float::INFINITY, divisor: 1_000_000, prefix: 'M' },
  ].freeze
  private_constant :SCALE_STEPS

  def scale_steps
    SCALE_STEPS
  end

  def label(prefix: '', context: :rate)
    "#{prefix}#{context == :total ? 'Wh' : 'W'}"
  end

  # Raw watts are whole numbers to begin with
  def precision(printed_value, divisor: 1)
    return 0 if divisor == 1

    decimal_while_short(printed_value)
  end

  # Three decimals of a kWh are watt-hours again
  def exact_precision
    3
  end
end
