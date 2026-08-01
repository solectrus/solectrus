class Sensor::Units::Unitless < Sensor::Units::Base
  def precision(_printed_value, **)
    1
  end
end
