# The tooltip of a place on the map of the places (see
# Car::PlaceTooltip::Component). The map loads it when the pointer rests on a
# place, so the page carries only the positions of the places. The hover over
# a place without a name is the request of the user, so Nominatim gives its
# address here (see Place#geocode!). The browser asks for one place at a
# time, and Place::Nominatim keeps one second between two requests.
class Cars::PlaceTooltipsController < ApplicationController
  include CarPageGate

  def show
    place = Place.find(params.expect(:place)).geocode!
    timeframe = Timeframe.new(params.expect(:timeframe))
    selection = CarSelection.new(params[:car], timeframe:)

    tooltip = Car::PlaceTooltip::Component.new(
      place:,
      cars: selection.cars,
      visits: PlaceVisit.where(car: selection.cars, place:, date: timeframe.effective_dates),
      visits_path: cars_visits_path(car: selection.to_param, place:, timeframe: (timeframe.to_param unless timeframe.all?)),
    )
    render tooltip, layout: false
  end
end
