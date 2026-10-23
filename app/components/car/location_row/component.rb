# The place of a car in the live view, as a pill that opens the map (see
# Car::Location::Component). A car at a place shows the name of the place. A
# car at no place is on the road: the row names the town near its latest
# position and how old that position is. A car that drove away from its
# latest position is on the road without a town (see
# Car::Live#left_location?). Home has the icon of a house.
#
# Nominatim can take a few seconds, so the live view does not wait for it.
# Without a known name (see Place.known_name_at), the row pulses and loads the
# name into its frame (see Cars::PlacesController). The next refresh of the
# live view then knows the name.
class Car::LocationRow::Component < ViewComponent::Base
  include Car::TimeText

  # Below this age, the row says how many minutes ago the car reported its
  # position. An older position names its time.
  RECENT = 1.hour
  private_constant :RECENT

  # `state` holds the values of one car (see Car::Live::State). `deferred`
  # loads an unknown name into the frame, which the answer of the frame does
  # not, so a name that Nominatim does not give stays away.
  def initialize(state:, deferred: true)
    super()
    @state = state
    @deferred = deferred
  end

  attr_reader :state

  delegate :car, :location, to: :state

  def place
    return @place if defined?(@place)

    @place = (Place.near(*location) if location)
  end

  def home? = place&.home? || false

  def on_the_road? = place.nil?

  def title = on_the_road? ? t('.on_the_road') : (place.display_name || t('.location'))

  # The town near the position of a car on the road, or nil before an answer
  # of Nominatim
  def town
    return @town if defined?(@town)

    @town = (Place.known_name_at(*location) if on_the_road? && location)
  end

  # A car on the road names the town and the age of its position
  def subtitle
    [(t('.near', town:) if town), age].compact.join(' · ') if on_the_road? && location
  end

  # Without a known name, the frame loads it. Without Nominatim, no name
  # comes, so the row does not wait for one.
  def src
    return unless @deferred && location && Place::Nominatim.enabled?
    return if place ? place.display_name : town

    helpers.cars_place_path(car: car.id)
  end

  def frame_id = "car_place_#{car.id}"

  # A car without a position has no map
  def tag_name = location ? :a : :div

  def link_options
    return {} unless location

    { href: helpers.cars_location_path(car: car.id), data: { turbo_frame: Car::MapOverlay::Component::FRAME_ID } }
  end

  def row_classes
    class_names(
      'inline-flex max-w-full items-center gap-2 min-h-9 pl-1 pr-3 py-1 rounded-full',
      'focus-ring-inset hover:bg-slate-100 dark:hover:bg-slate-700/50 click-animation' => location,
    )
  end

  private

  def age
    time = state.located_at
    return unless time

    minutes = ((Time.current - time) / 60).floor
    minutes < RECENT.in_minutes ? t('.minutes_ago', count: minutes) : time_text(time)
  end
end
