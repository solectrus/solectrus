# The longitude of the location of a car, in degrees. It is personal data, so
# only the admin sees it (see CarLocationChart).
class Sensor::Definitions::CarLongitude < Sensor::Definitions::Base
  include Sensor::Definitions::CarNumber

  value unit: :unitless, range: (-180..180), category: :car

  icon 'location-dot'

  # A car reports a change of its state, often only while it is online,
  # so the value holds until the next reading
  state

  requires_permission :car

  personal
end
