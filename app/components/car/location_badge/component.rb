# The place of a car in the live view, as a badge that opens the map (see
# Car::Location::Component). It shows the name of the place, or else the
# town of the location.
#
# Nominatim can take a few seconds, so the live view does not wait for it.
# Without a known name (see Place.known_name_at), the badge pulses and loads
# the name into its frame (see Cars::PlacesController). The next refresh of
# the live view then knows the name. Without an answer of Nominatim, the
# badge shows a generic label.
class Car::LocationBadge::Component < ViewComponent::Base
  # `name` is the name of the place, or nil. `deferred` loads the name into
  # the frame.
  def initialize(car:, name:, deferred: false)
    super()
    @car = car
    @name = name
    @deferred = deferred
  end

  attr_reader :car, :name

  def frame_id = "car_place_#{car.id}"

  # Without Nominatim, no name comes, so the badge does not wait for one
  def src = (helpers.cars_place_path(car: car.id) if @deferred && Place::Nominatim.enabled?)
end
