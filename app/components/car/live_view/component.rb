# The live view of the car page: a cell for each car in use today with its
# name, the gauge of its range and its odometer. The gauge shows the plug of
# the car, and next to it the charging power: the power of the wallbox for
# the car at the wallbox, else zero (see Car::Live). Below the odometer, the
# admin sees the town of the location, which opens the map. The live view has
# no chart, so the cars take its place.
#
# Below the cars, the charging power of the wallbox shows only when no car
# shows it: a guest charges, or no car has a plug. The plug of the wallbox
# shows only when no car has a plug, for example with two cars and no plug of
# a car.
class Car::LiveView::Component < ViewComponent::Base
  PILL_CLASSES =
    'flex items-center gap-2 rounded-full px-4 py-1.5 md:py-2 text-sm md:text-base ' \
    'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-400'.freeze
  private_constant :PILL_CLASSES

  # `live` is a Car::Live. `named` shows the name of each car, because the
  # live view has no select of the car.
  def initialize(live:, named:)
    super()
    @live = live
    @named = named
  end

  attr_reader :live

  def named? = @named

  delegate :wallbox_power, :wallbox_car_connected, to: :live

  def wallbox? = wallbox_power? || wallbox_plug?

  def wallbox_power? = !wallbox_power.nil? && !live.car_at_wallbox? && (charging? || states.all? { it.charging_power.nil? })

  def wallbox_plug? = !wallbox_car_connected.nil? && states.all? { it.connected.nil? }

  def charging? = wallbox_power.to_f.positive?

  def pill_classes(**) = class_names(PILL_CLASSES, **)

  def states
    @states ||= live.states
  end

  # The time of the latest reading of the car. A car sensor holds its value
  # at any age, so the live view always tells how old it is: the time of
  # today, or else the day and the time.
  def as_of(state)
    time = state.time
    return unless time

    l(time, format: time.today? ? :now : :short)
  end

  # The location is personal data, so only the admin sees it
  def location?(state) = helpers.admin? && !state.location.nil?

  # The name of the place of the car. The live view does not wait for
  # Nominatim, so an unknown name comes later (see Car::LocationBadge::Component).
  def place_name(state) = Place.known_name_at(*state.location)

  # A cell keeps a minimum height, so a narrow screen scrolls through the
  # cars. The class names stay literal, so Tailwind finds them.
  def grid_classes
    case states.size
    when 1 then 'grid-cols-1'
    when 3 then 'grid-cols-1 sm:grid-cols-2 lg:grid-cols-3'
    else 'grid-cols-1 sm:grid-cols-2'
    end
  end
end
