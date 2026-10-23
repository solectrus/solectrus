# The places of the cars on a map that fills the window over the list of the
# places (see Place::Map::Component and Car::MapOverlay::Component). The
# tooltip of a place links the visits of the place. The map has no page of
# its own, so its address alone leads to the list.
class Cars::PlaceMapsController < ApplicationController
  include Cars::PlacePage

  def index
    return redirect_to(place_list_path('places')) unless turbo_frame_request?

    # A car that the page does not offer goes to "all", like on the car page
    redirect_to(page_path_with(car: nil)) unless car_selection.valid?
  end

  private

  def page_route = :cars_place_map_path

  helper_method def map_component
    Place::Map::Component.new(
      cars: car_selection.cars,
      timeframe:,
      tooltip_url: cars_place_tooltip_path(car: car_selection.to_param, place: ':id', timeframe: timeframe.to_param),
    )
  end
end
