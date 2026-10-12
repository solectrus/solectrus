# A sensor without a unit -- it has a value, but nothing to print it as
class Sensor::Units::Null < Sensor::Units::Base
  # A raw reading needs a unit to say what it is
  def parse(_raw_value)
    raise ArgumentError, 'Unknown unit type'
  end

  def format(_printed_value, **)
    ''
  end
end
