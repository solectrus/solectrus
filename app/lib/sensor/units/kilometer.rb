class Sensor::Units::Kilometer < Sensor::Units::Base
  def label(**)
    'km'
  end

  # Distances are read as whole kilometres -- a car's odometer and its range
  # are never quoted to the metre.
  def default_context
    :total
  end
end
