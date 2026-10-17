# The places of the cars on a map that fills the page (see
# Place::Map::Component), a page below the car page like the list of the
# visits. The tooltip of a place links the visits of the place.
class Cars::PlaceMapsController < ApplicationController
  include PlacePage

  def index
    # A car that the page does not offer goes to "all", like on the car page
    return redirect_to(page_path_with(car: nil)) unless car_selection.valid?

    # While days wait for the build, the page shows the build instead of the map
    @pending_days = Sensor::Summarizer.build_few(pending_visit_days)
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

  helper_method def title
    t('car_breakdown.places')
  end
end
