class Sensor::Units::KwhPer100km < Sensor::Units::Base
  def default_context
    :total
  end

  def label(**)
    'kWh/100 km'
  end

  # A consumption reads to a tenth: 18.4 kWh/100 km
  def precision(_printed_value, **)
    1
  end

  def exact_precision
    1
  end
end
