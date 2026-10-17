# The places of the cars on a map that fills the page (see
# Cars::PlaceMapsController). A circle marks a place, and its area
# shows the share of the time of the cars at that place. The circles have one
# color for each selection of cars, so the map of one car looks like the map
# of all cars. The page carries only the circles, and the map loads the
# tooltip of a place when the pointer rests on it (see
# Cars::PlaceTooltipsController).
#
# The time comes from the visits of the daily build (see
# Place::VisitDetection), so the page builds the days first (see
# PlaceVisitsBuild). A day outside the period of use of a car has no visit of
# it.
class Place::Map::Component < ViewComponent::Base
  # `tooltip_url` holds the tooltip of a place with ":id" for its id
  def initialize(cars:, timeframe:, tooltip_url:)
    super()
    @cars = cars
    @timeframe = timeframe
    @tooltip_url = tooltip_url
  end

  attr_reader :tooltip_url

  # [[latitude, longitude, share of the time, id], ...] (see
  # Car::Map::Component), the longest time first. One query gives the time
  # and the position of each place.
  def places
    @places ||= begin
      seconds =
        PlaceVisit.where(car: @cars, date: @timeframe.effective_dates).joins(:place)
          .group(:place_id, 'places.latitude', 'places.longitude').sum(:seconds)
      total = seconds.values.sum

      seconds.sort_by { -it.last }.map do |(id, latitude, longitude), time|
        [latitude.round(5), longitude.round(5), total.positive? ? time.fdiv(total).round(4) : 0, id]
      end
    end
  end
end
