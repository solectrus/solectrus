# The name of the place of a car, for the row of the live view (see
# Car::LocationRow::Component). The live view shows the row at once and loads
# an unknown name here, because Nominatim can take a few seconds. The location
# is personal data, so only the admin gets it.
class Cars::PlacesController < ApplicationController
  include Cars::PageGate

  def show
    return redirect_to(cars_home_path) unless turbo_frame_request?

    @state = Car::Live.new([car]).states.sole
    # Asks Nominatim, so the row knows the name (see Place.name_at)
    Place.name_at(*@state.location) if @state.location
  end

  private

  def car
    Car.find_configured!(params[:car])
  end
end
