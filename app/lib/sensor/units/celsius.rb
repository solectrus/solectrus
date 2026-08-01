class Sensor::Units::Celsius < Sensor::Units::Base
  def label(**)
    '°C'
  end

  def precision(_printed_value, **)
    1
  end
end
