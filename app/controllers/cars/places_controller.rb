# The name of the place of a car, for the badge of the live view (see
# Car::LocationBadge::Component). The live view shows the badge at once and
# loads an unknown name here, because Nominatim can take a few seconds. The
# location is personal data, so only the admin gets it.
class Cars::PlacesController < ApplicationController
  include CarPageGate

  def show
    return redirect_to(cars_home_path) unless turbo_frame_request?

    @car = car
    location = Car::Live.new([@car]).states.sole.location
    @name = Place.name_at(*location) if location
  end

  private

  def car
    Car.find_configured!(params[:car])
  end
end
