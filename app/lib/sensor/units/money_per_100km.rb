class Sensor::Units::MoneyPer100km < Sensor::Units::Base
  def default_context
    :total
  end

  def label(**)
    "#{Currency.symbol}/100 km"
  end

  # A cost per distance is a few currency units, so the cents matter
  def precision(_printed_value, **)
    2
  end
end
