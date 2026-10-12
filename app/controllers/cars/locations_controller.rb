# The location of one car on a map that fills the window (see
# Car::Location::Component). The location is personal data, so only the admin
# gets it.
#
# The name of the location asks Nominatim when necessary, but makes no place
# (see Place.name_at). The car can be on the road, and only the daily build
# makes a place where a car stood (see Place.of).
class Cars::LocationsController < ApplicationController
  include CarPageGate

  def show
    return redirect_to(cars_home_path) unless turbo_frame_request?

    @state = Car::Live.new([car]).states.sole
    @name = Place.name_at(*@state.location) if @state.location
  end

  private

  def car
    Car.find_configured!(params[:car])
  end
end
