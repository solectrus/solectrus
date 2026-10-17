# The live view of the car page: a cell for each car in use today with its
# name, the gauge of its range (a bar for several cars on a phone) and its
# odometer. The name shows also for the only car, because the live view has
# no select of the car. The gauge shows the plug of the car, and next to it
# the charging power: the power of the wallbox for the car at the wallbox,
# else zero (see Car::Live). Below the odometer, the admin sees the town of
# the location, which opens the map. The live view has no chart, so the cars
# take its place.
#
# Below the cars, the charging power of the wallbox shows only when no car
# shows it: a guest charges, or no car has a plug. The plug of the wallbox
# shows only when no car has a plug, for example with two cars and no plug of
# a car.
#
# Without a car in use today, a gray gauge with a note takes the place
# of the cars.
class Car::LiveView::Component < ViewComponent::Base
  PILL_CLASSES =
    'flex items-center gap-2 rounded-full px-4 py-1.5 md:py-2 text-sm md:text-base ' \
    'bg-slate-100 dark:bg-slate-800'.freeze
  private_constant :PILL_CLASSES

  # `live` is a Car::Live
  def initialize(live:)
    super()
    @live = live
  end

  attr_reader :live

  delegate :wallbox_power, :wallbox_car_connected, to: :live

  def wallbox? = wallbox_power? || wallbox_plug?

  def wallbox_power? = !wallbox_power.nil? && !live.car_at_wallbox? && (charging? || states.all? { it.charging_power.nil? })

  def wallbox_plug? = !wallbox_car_connected.nil? && states.all? { it.connected.nil? }

  def charging? = wallbox_power.to_f.positive?

  def pill_classes(charging: false) = class_names(PILL_CLASSES, Car::BatteryDisplay.charging_classes(charging))

  def states
    @states ||= live.states
  end

  # The state of the inactive gauge while no car is in use today
  def placeholder_state = Car::Live::State.new(car: nil, soc: nil, range: nil, max_range: nil, odometer: nil, connected: nil, charging_power: nil, latitude: nil, longitude: nil)

  # The time of the latest reading of the car. A car sensor holds its value
  # at any age, so the live view always tells how old it is: the time of
  # today, "Yesterday" and the time, the weekday and the time within the last
  # six days, or else the date and the time. Within six days, no weekday comes
  # twice, so the weekday is clear.
  def as_of(state)
    time = state.time
    return unless time

    if time.today?
      l(time, format: :now)
    elsif time.yesterday?
      t('.yesterday', time: l(time, format: :now))
    elsif time.to_date > 7.days.ago.to_date
      t('.weekday', day: l(time, format: '%A'), time: l(time, format: :now))
    else
      l(time, format: :short)
    end
  end

  # The location is personal data, so only the admin sees it
  def location?(state) = helpers.admin? && !state.location.nil?

  # The name of the place of the car. The live view does not wait for
  # Nominatim, so an unknown name comes later (see Car::LocationBadge::Component).
  def place_name(state) = Place.known_name_at(*state.location)

  # The only car shows its battery as a gauge. With more cars, a gauge for
  # each does not fit on a phone, so a phone shows a bar for each car, and a
  # wider screen the gauges.
  SEVERAL_VARIANTS = %i[bar gauge].freeze
  private_constant :SEVERAL_VARIANTS

  ONE_VARIANT = %i[gauge].freeze
  private_constant :ONE_VARIANT

  def variants = several? ? SEVERAL_VARIANTS : ONE_VARIANT

  def several? = states.size > 1

  def battery_component(variant) = variant == :bar ? Car::RangeBar::Component : Car::RangeGauge::Component

  # The class names stay literal, so Tailwind finds them
  VARIANT_CLASSES = { bar: 'sm:hidden', gauge: 'max-sm:hidden' }.freeze
  private_constant :VARIANT_CLASSES

  def variant_classes(variant)
    class_names('flex flex-1 min-h-0 w-full flex-col items-center', (VARIANT_CLASSES[variant] if several?))
  end

  # A cell of a gauge keeps a minimum height of 24rem, so a narrow screen
  # scrolls through the cars. Less the name and the odometer, it leaves the
  # gauge 15rem wide: below that, the center of the gauge reaches the arc,
  # because its text stops shrinking (see Car::RangeGauge::Component). On a
  # phone, a cell of a bar keeps the height of its content. The row of the
  # line between two bars grows from 2rem to 5rem with the room that the bars
  # leave free, so a low screen keeps the bars on it and a high one gives
  # them air. The bars stand together in the middle. The class names stay
  # literal, so Tailwind finds them.
  def row_classes
    if several?
      'max-sm:auto-rows-[min-content_minmax(2rem,5rem)] max-sm:gap-y-0 content-center-safe ' \
        'sm:auto-rows-[minmax(24rem,1fr)] sm:content-normal'
    else
      'auto-rows-[minmax(24rem,1fr)]'
    end
  end

  def grid_classes
    case states.size
    when 0, 1 then 'grid-cols-1'
    when 3 then 'grid-cols-1 sm:grid-cols-2 lg:grid-cols-3'
    else 'grid-cols-1 sm:grid-cols-2'
    end
  end
end
