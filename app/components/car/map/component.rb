# A map of the places of cars, drawn by MapLibre with the vector tiles of
# OpenFreeMap. A period shows a circle for each place of the cars (see
# Sensor::Chart::CarLocation). The live view shows the latest location of one
# car (see Car::Location::Component).
#
# The location is personal data, so the caller gives the places to the admin
# only.
class Car::Map::Component < ViewComponent::Base
  # `cars` is [{ places: [[latitude, longitude, share, id], ...] }], and each
  # place has the same color.
  # A `live` map shows one location as a marker, without a tooltip. With a
  # `tooltip_timeframe`, the map loads the tooltip of a place in this
  # timeframe when the pointer rests on it (see #tooltip_url).
  def initialize(cars:, live: false, tooltip_timeframe: nil)
    super()
    @cars = cars
    @live = live
    @tooltip_timeframe = tooltip_timeframe
  end

  attr_reader :cars

  # The tooltip of a place, with ":id" for the id of the place, like
  # "/cars/places/:id/tooltip/2026" (see Cars::PlaceTooltipsController).
  # Rails takes the selected car from the current address, so the tooltip
  # has the cars of the map.
  def tooltip_url
    return unless @tooltip_timeframe

    @tooltip_url ||= helpers.cars_place_tooltip_path(place: ':id', timeframe: @tooltip_timeframe.to_param)
  end

  def live? = @live

  # A map of a period reaches the edges of the card, so only its side toward
  # the stats is round
  def root_classes
    class_names(
      'flex flex-1 flex-col size-full min-h-20 overflow-hidden bg-slate-100 dark:bg-slate-800',
      live? ? 'rounded-lg' : 'lg:landscape:rounded-l-lg',
      # A zoomed map reaches the edges of the window (see ChartLoader::Component)
      'group-data-zoomed/zoom:rounded-none',
    )
  end
end
