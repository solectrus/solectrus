# The card of one car in the live view (see Car::LiveView::Component), in the
# way of the grouped lists of iOS: its name with a car in its color and the
# time of its latest reading, then a card with its range and its state of
# charge as a bar with the scale from 0 to the maximum range. Below it, the
# cells of a list: for the admin its place, the plug and the odometer. The
# range, the bar and the odometer open the chart of today.
#
# A phone has white cards on the gray of the page, the desktop gray cards on
# its white page. A lone car on the desktop has the list beside the card.
# With more than one card, the card is a little smaller, so two cars fit on a
# phone with less scrolling.
class Car::LiveCard::Component < ViewComponent::Base
  include Car::BatteryDisplay
  include Car::TimeText

  # The color of the fill for each level of the state of charge (see
  # Sensor::Definitions::CarBatterySoc.level): red, yellow, then the blue of
  # the battery. The yellow has dark text for contrast. The class names stay
  # literal, so Tailwind finds them.
  FILL_CLASSES = {
    critical: 'bg-signal-negative text-white',
    low: 'bg-amber-400 text-slate-900',
    good: 'bg-car-battery text-white',
  }.freeze
  private_constant :FILL_CLASSES

  # Below this state of charge, the percent stands beside the fill, which
  # has no room for it
  INSIDE_MIN = 20
  private_constant :INSIDE_MIN

  # `state` holds the values of one car (see Car::Live::State). `compact` is
  # whether the phone shows more than one card.
  def initialize(state:, compact: false)
    super()
    @state = state
    @compact = compact
  end

  attr_reader :state, :compact

  # The ground of the card and of the list. The dark page of the desktop has
  # the color of the canvas, so the card takes the surface and a fine edge
  # there.
  GROUND = 'bg-surface lg:bg-canvas dark:lg:bg-surface dark:lg:ring-1 dark:lg:ring-white/10'.freeze
  public_constant :GROUND

  # A lone car on the desktop has the room for its list beside the card. The
  # class names stay literal, so Tailwind finds them.
  def body_classes = compact ? 'contents' : 'contents lg:grid lg:grid-cols-[3fr_2fr] lg:gap-6'

  # The class names stay literal, so Tailwind finds them
  def range_size_class = compact ? 'text-4xl lg:text-6xl' : 'text-5xl lg:text-6xl'

  # The bar with its percent, the scale below it and the odometer, a step
  # larger for a lone card, which has the room for it
  def bar_height_class = compact ? 'h-8' : 'h-10'
  def percent_size_class = compact ? 'text-sm' : 'text-lg'
  def scale_size_class = compact ? 'text-xs' : 'text-sm'

  delegate :car, to: :state

  def time = time_text(state.time)

  # The location is personal data, so only the admin sees it. A car with a
  # location sensor but without a position drove away from it, so its row
  # says that it is on the road.
  def location? = helpers.admin? && car.located?

  def odometer? = sensor?(:car_odometer)

  # A value of the car opens today on the car page, with the car selected,
  # where the timeline of the day shows it (see Car::DayTimeline::Component):
  # the state of charge as its line, the odometer as the drives. The range
  # has no line there, so it links nowhere.
  DAY_SENSORS = { soc: :car_battery_soc, odometer: :car_odometer }.freeze
  private_constant :DAY_SENSORS

  LINK_CLASSES = 'click-animation focus-ring'.freeze
  private_constant :LINK_CLASSES

  # A value (see DAY_SENSORS) as a link to today, or as a plain block
  # without one
  def value_tag(value, **options, &)
    path = day_path(value)
    content_tag(path ? :a : :div, **options, href: path, class: class_names(options[:class], LINK_CLASSES => path), &)
  end

  def fill_classes = FILL_CLASSES[Sensor::Definitions::CarBatterySoc.level(soc)]

  # The percent takes the color of the text of the fill, or beside the fill
  # the color of the scale
  def percent_classes
    percent_inside? ? fill_classes.split.grep(/\Atext-/) : 'text-fg-secondary'
  end

  def bar_label
    "#{t('sensors.car_battery_soc_short')} #{soc ? percent : '–'}"
  end

  def percent_inside? = soc >= INSIDE_MIN

  def percent = "#{soc.round} %"

  # The percent stands at the end of the fill, or beside it
  def percent_style
    percent_inside? ? "right: calc(100% - #{fill_percent}% + 0.75rem)" : "left: calc(#{fill_percent}% + 0.75rem)"
  end

  # The plug of the car, or the charging power while it charges
  def plug? = charging? || !state.connected.nil?

  # The state of the plug as the value of its cell: the charging power in
  # green, or whether the car is connected
  def plug_state
    text, classes =
      if charging?
        [t('.charging', power: power_text), 'font-semibold tabular-nums text-signal-positive']
      elsif state.connected
        [t('sensors.wallbox_car_connected_short'), 'text-car-battery']
      else
        [t('sensors.wallbox_car_disconnected_short'), 'text-muted']
      end

    tag.span(safe_join([helpers.icon(charging? ? 'bolt' : 'plug'), text]), class: ['flex items-center gap-1.5', classes])
  end

  def power_text = Sensor::ValueFormatter.new(charging_power, unit: Sensor::Registry[:wallbox_power].unit, context: :rate).to_s

  private

  def day_path(value)
    role = DAY_SENSORS[value]
    helpers.cars_home_path(car: car.id, timeframe: 'day') if role && sensor?(role)
  end
end
