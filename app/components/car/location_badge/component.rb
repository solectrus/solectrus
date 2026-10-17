# The place of a car in the live view, as a badge that opens the map (see
# Car::Location::Component). It shows the name of the place, or else the
# town of the location.
#
# Nominatim can take a few seconds, so the live view does not wait for it.
# Without a known name (see Place.known_name_at), the badge pulses and loads
# the name into its frame (see Cars::PlacesController). The next refresh of
# the live view then knows the name. Without an answer of Nominatim, the
# badge shows a generic label. A frame that the screen hides does not load.
class Car::LocationBadge::Component < ViewComponent::Base
  # The frames that a car can show at the same time: the live view with
  # several cars has a badge in the bar and one in the gauge (see
  # Car::LiveView::Component)
  FRAMES = %w[bar gauge].freeze
  private_constant :FRAMES

  # `name` is the name of the place, or nil. `deferred` loads the name into
  # the frame. `frame` is one of FRAMES, so each badge of a car has a frame
  # of its own.
  def initialize(car:, name:, deferred: false, frame: nil)
    super()
    @car = car
    @name = name
    @deferred = deferred
    @frame = frame&.to_s.presence_in(FRAMES)
  end

  attr_reader :car, :name, :frame

  # In the bar, the badge is a link in the line of the time, without a
  # background of its own
  def inline? = frame == 'bar'

  # The class names stay literal, so Tailwind finds them
  def link_classes
    if inline?
      'flex items-center min-w-0 max-w-full gap-1 rounded hover:text-slate-700 dark:hover:text-slate-200 focus-ring'
    else
      'flex items-center min-w-0 max-w-full gap-1.5 rounded-full h-[clamp(1.75rem,7.5cqi,2.25rem)] px-[clamp(0.75rem,4cqi,1.25rem)] ' \
        'bg-slate-100 hover:bg-slate-200 dark:bg-slate-800 dark:hover:bg-slate-700 text-slate-600 dark:text-slate-400 focus-ring-inset'
    end
  end

  def frame_id = ['car_place', car.id, frame].compact.join('_')

  # Without Nominatim, no name comes, so the badge does not wait for one
  def src = (helpers.cars_place_path(car: car.id, frame:) if @deferred && Place::Nominatim.enabled?)
end
