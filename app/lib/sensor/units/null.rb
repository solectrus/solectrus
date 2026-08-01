# A sensor without a unit -- it has a value, but nothing to print it as
class Sensor::Units::Null < Sensor::Units::Base
  def format(_printed_value, **)
    ''
  end
end
