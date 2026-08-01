class Sensor::Units::Money < Sensor::Units::Base
  def default_context
    :total
  end

  def label(context: :rate, **)
    context == :rate ? "#{Currency.symbol}/h" : Currency.symbol
  end

  # Cents matter for small amounts, not for large ones
  def precision(printed_value, **)
    printed_value.abs >= 10 ? 0 : 2
  end
end
