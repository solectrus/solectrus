# The latest location of one car on a map. A click on the place in the live
# view loads it into the frame FRAME_ID, and it fills the window like a zoomed
# chart. The close button and ESC empty the frame again.
#
# The frame is outside the live view, so the refresh of the live view keeps
# the map (see the car page).
class Car::Location::Component < ViewComponent::Base
  FRAME_ID = 'car_location'.freeze
  public_constant :FRAME_ID

  # `location` is [latitude, longitude], or nil without one. `name` is the
  # name at the location (see Place.name_at), or nil without an answer of
  # Nominatim.
  def initialize(car:, location:, name:)
    super()
    @car = car
    @location = location
    @name = name
  end

  attr_reader :car, :location, :name

  # The data of Car::Map::Component: the location as its one place
  def map_cars
    [{ places: [[*location, 1]] }]
  end
end
