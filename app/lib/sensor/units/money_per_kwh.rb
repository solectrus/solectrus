class Sensor::Units::MoneyPerKwh < Sensor::Units::Base
  def label(**)
    "#{Currency.symbol}/kWh"
  end

  # Prices are quoted to a hundredth of a cent
  def precision(_printed_value, **)
    4
  end

  def exact_precision
    4
  end
end
