# The card of one car in the live view (see Car::LiveView::Component), in the
# way of the grouped lists of iOS: its name with a car in its color, then a
# card with its range, the time of its latest reading and its state of
# charge as a bar with the scale from 0 to the maximum range. Below it, a
# list: for the admin the map of its place, then the plug and the odometer.
# The range, the bar and the odometer open the chart of today.
#
# A phone has white cards on the gray of the page, the desktop gray cards on
# its white page. The list of the admin folds into one cell with the place
# and the plug, and a tap on that cell unfolds it in its place (see
# component_controller.ts). A lone card starts unfolded. With more than one
# card, the card is a little smaller and starts folded, so several cars fit
# on a phone without a scroll.
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
  # whether the live view shows more than one card.
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

  # The class names stay literal, so Tailwind finds them
  def range_size_class = compact ? 'text-4xl lg:text-6xl' : 'text-5xl lg:text-6xl'

  # The bar with its percent, a step larger for a lone card, which has the
  # room for it
  def bar_height_class = compact ? 'h-8' : 'h-10'
  def percent_size_class = compact ? 'text-sm' : 'text-lg'

  delegate :car, to: :state

  # How long ago the latest reading came, with its time in the tooltip
  def time_ago = time_ago_text(state.time)

  # The time of the latest reading as a sentence: today the time alone, then
  # "yesterday", the weekday within the last six days, or else the date
  def time_title
    time = state.time
    at = l(time, format: :now)

    case day_of(time)
    when :today then t('.as_of.today', time: at)
    when :yesterday then t('.as_of.yesterday', time: at)
    when :weekday then t('.as_of.day', day: l(time, format: '%A'), time: at)
    else t('.as_of.day', day: l(time.to_date, format: :short).strip, time: at)
    end
  end

  # The location is personal data, so only the admin sees it. A car with a
  # location sensor but without a position drove away from it, so its row
  # says that it is on the road.
  def location?
    return @location if defined?(@location)

    @location = helpers.admin? && car.located?
  end

  def odometer? = sensor?(:car_odometer)

  # The map of the place, for a car with a position
  def map? = location? && state.location.present?

  # Without a position, a cell in place of the map says that the car is on the
  # road
  def road_cell? = location? && !map?

  # The cells below the map
  def cells? = road_cell? || plug? || odometer?

  # The list below the card: the map and the cells
  def details? = map? || cells?

  # A lone card on a wide screen has the room for its cells side by side. The
  # class names stay literal, so Tailwind finds them.
  def cells_classes = ['divide-y divide-line', ('lg:grid lg:grid-flow-col lg:auto-cols-fr lg:divide-x lg:divide-y-0' unless compact)]

  # Side by side, a cell shows its value alone, in the middle: the icon tells
  # it, and the odometer names itself in its tooltip
  def cell_classes = [CELL, ('lg:justify-center' unless compact)]

  def cell_label_class = ('lg:hidden' unless compact)

  # A lone card on a phone gives the rest of the height of the window to its
  # map, while its list is unfolded
  def fill? = !compact && map?

  # The class names stay literal, so Tailwind finds them
  def map_classes = ['flex lg:h-80 border-fg/15 *:rounded-none', fill? ? 'min-h-56 max-lg:flex-1' : 'h-56']

  # The map loads the location of the car. A move of the car changes the
  # address, so the map loads again (see component_controller.ts).
  def map_path = helpers.cars_location_path(car: car.id, at: state.location.join(','))

  # The list of the admin folds into one cell with the place and the plug,
  # when it holds more than that cell. A visitor sees no place and no map, so
  # the short list of a visitor stays as it is.
  def fold? = location? && (map? || plug? || odometer?)

  def details_id = "car-live-details-#{car.id}"

  # A lone card has the room for its list
  def open_at_start? = !compact

  # The refresh of the live view keeps the state of the card and its map
  # (see component_controller.ts)
  FOLD_ACTIONS = 'turbo:before-morph-attribute->car--live-card--component#keepState ' \
                 'turbo:before-morph-element->car--live-card--component#keepMap'.freeze
  private_constant :FOLD_ACTIONS

  def fold_data = fold? ? { controller: 'car--live-card--component', action: FOLD_ACTIONS, open: open_at_start?.to_s } : {}

  # The cell that unfolds the list, and the cell that folds it again. The class
  # names stay literal, so Tailwind finds them.
  TOGGLE_CLASSES = 'w-full text-left focus-ring-inset hover:bg-fill-strong active:bg-fill-strong'.freeze
  private_constant :TOGGLE_CLASSES

  def toggle_options
    {
      type: 'button',
      'aria-expanded': open_at_start?.to_s,
      'aria-controls': details_id,
      data: { action: 'car--live-card--component#toggle', 'car--live-card--component-target': 'toggle' },
    }
  end

  # A cell of the list: its name at the left, its value at the right
  CELL = 'flex items-center justify-between gap-3 min-h-12 px-4 py-2.5 text-base text-fg lg:px-6'.freeze
  private_constant :CELL

  # The place at the position of the car, or nil on the road
  def place
    return @place if defined?(@place)

    @place = (Place.near(*state.location) if state.location)
  end

  # The name of the place, or none for a place without a name yet
  def place_name = place ? place.display_name : t('.on_the_road')

  # The icon and the name of the place, in the folded cell and on the road
  def place_tag(css_class = nil)
    name = tag.span(place_name, class: 'truncate text-fg-secondary') if place_name
    tag.span(safe_join([render(Place::Icon::Component.new(place:, round: true)), name]), class: ['flex min-w-0 items-center gap-2', css_class])
  end

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

  # A car away from home is not at the wallbox, but can be connected to any
  # other charger, so its cell names the plug alone
  def plug_label = state.away ? t('.plug') : t('car_breakdown.wallbox_short')

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
