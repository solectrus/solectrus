# A map of the places of cars, drawn by MapLibre with the vector tiles of
# OpenFreeMap. A period shows a circle for each place of the cars (see
# Place::Map::Component). The live view shows the latest location of one car
# (see Car::Location::Component). These two fill the window over their page
# (see Car::MapOverlay::Component).
#
# The location is personal data, so the caller gives the places to the admin
# only.
class Car::Map::Component < ViewComponent::Base
  # `cars` is [{ places: [[latitude, longitude, share, id], ...] }], and each
  # place has the same color. A place can add an address as its fifth item,
  # and a click on the place opens it, like the form of a charging session.
  # A `live` map shows one location as a marker, without a tooltip. A live
  # map with a `name` shows it next to its marker. A `movable` map is a live
  # map whose marker the user moves (see movable_point.ts). With a
  # `tooltip_url`, which holds ":id" for the id of a place, the map loads the
  # tooltip of a place when the pointer rests on it, like
  # "/cars/places/:id/tooltip/2026" (see Cars::PlaceTooltipsController).
  def initialize(cars:, live: false, name: nil, movable: false, tooltip_url: nil)
    super()
    @cars = cars
    @live = live || movable
    @movable = movable
    @name = name
    @tooltip_url = tooltip_url
  end

  attr_reader :cars, :name, :tooltip_url

  def live? = @live

  # The texts of a movable map, or nil for a map that does not move. The map
  # puts the name of a station for "{name}".
  def movable_texts
    return unless @movable

    { hint: t('.move_hint'), station: t('.station', name: '{name}'), unnamedStation: t('.unnamed_station') }
  end

  # A map of a period fills the window (see Car::MapOverlay::Component), with
  # a minimum for a short window. A live map stands inside its box.
  def root_classes
    class_names(
      'flex flex-1 flex-col overflow-hidden rounded-lg bg-slate-100 dark:bg-slate-800',
      live? ? 'size-full min-h-20' : 'relative min-h-80',
    )
  end
end
