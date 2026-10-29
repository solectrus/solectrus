# The latest location of one car on a map, in the list of the car in the live
# view (see Car::LiveCard::Component). The list loads it into its frame once
# the list shows, so a folded list loads no map.
class Car::Location::Component < ViewComponent::Base
  def self.frame_id(car) = "car_location_#{car.id}"

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
