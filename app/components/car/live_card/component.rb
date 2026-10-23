# The card of one car in the live view (see Car::LiveView::Component): its
# name with a car in its color and the time of its latest reading, for the
# admin the row of its place, then its range, its state of charge as a bar
# with the scale from 0 to the maximum range, the plug, and the odometer at
# the foot. The range, the bar and the odometer open the chart of today.
#
# The plug is an icon. While the car charges, it is green with the charging
# power beside it. It stands in the middle below the bar.
#
# A phone shows the cards one below the other. With more than one card, the
# phone has a compact card, so two cars fit without scrolling: the range
# with its name in one line, and the plug on the right of it.
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

  # The class names stay literal, so Tailwind finds them
  def range_row_class = compact ? 'flex items-center justify-between gap-3 sm:justify-center' : 'flex justify-center'

  def range_class = compact ? 'flex items-baseline gap-2 sm:flex-col sm:items-center sm:gap-1.5' : 'flex flex-col items-center gap-1.5'

  def range_size_class = compact ? 'text-4xl sm:text-5xl lg:text-6xl' : 'text-5xl lg:text-6xl'

  def range_name_class = ('max-sm:normal-case max-sm:tracking-normal' if compact)

  def content_gap_class = compact ? 'gap-3 sm:gap-4 lg:gap-5' : 'gap-4 lg:gap-5'

  # The bar with its percent, the scale below it and the odometer, a step
  # larger for a lone card, which has the room for it
  def bar_height_class = compact ? 'h-8' : 'h-10'
  def percent_size_class = compact ? 'text-sm' : 'text-lg'
  def scale_size_class = compact ? 'text-xs' : 'text-sm'
  def odometer_size_class = compact ? 'text-sm' : 'text-base'

  # The plug on the right of the range, on a compact phone card alone
  def inline_plug? = compact && plug?

  def plug_class = ('max-sm:hidden' if compact)

  delegate :car, to: :state

  def time = time_text(state.time)

  # The location is personal data, so only the admin sees it. A car with a
  # location sensor but without a position drove away from it, so its row
  # says that it is on the road.
  def location? = helpers.admin? && car.located?

  def odometer? = sensor?(:car_odometer)

  # A value of the car opens the chart of today on the car page, with the
  # car selected: the state of charge and the range their own chart, the
  # odometer the distance. A value without such a chart, for example an
  # estimated range, links nowhere.
  DAY_CHARTS = { soc: :car_battery_soc, range: :car_range, odometer: :car_distance }.freeze
  private_constant :DAY_CHARTS

  LINK_CLASSES = 'click-animation focus-ring'.freeze
  private_constant :LINK_CLASSES

  # A value (see DAY_CHARTS) as a link to its chart, or as a plain block
  # without one
  def value_tag(value, **options, &)
    path = chart_path(value)
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

  def plug_label
    if charging?
      t('.charging', power: power_text)
    else
      t(state.connected ? 'sensors.wallbox_car_connected_short' : 'sensors.wallbox_car_disconnected_short')
    end
  end

  def plug
    tag.span(class: plug_classes, role: 'img', title: plug_label, aria: { label: plug_label }, data: { controller: 'tooltip', tooltip_touch_value: 'true' }) do
      safe_join([helpers.icon(charging? ? 'bolt' : 'plug'), (tag.span(power_text, aria: { hidden: true }) if charging?)])
    end
  end

  def power_text = Sensor::ValueFormatter.new(charging_power, unit: Sensor::Registry[:wallbox_power].unit, context: :rate).to_s

  def plug_classes
    class_names(
      'flex shrink-0 items-center justify-center gap-1.5 rounded-full h-9 min-w-9 lg:h-11 lg:min-w-11 lg:gap-2 text-base lg:text-lg',
      if charging?
        'px-3 lg:px-4 font-semibold tabular-nums text-white bg-signal-positive'
      elsif state.connected
        'text-car-battery bg-fill'
      else
        'text-faint bg-fill'
      end,
    )
  end

  private

  def chart_path(value)
    sensor_name = DAY_CHARTS[value]
    helpers.cars_home_path(car: car.id, sensor_name:, timeframe: 'day') if day_chart?(sensor_name)
  end

  # Whether the car page draws the chart of today for the car. The chart
  # needs the sensor of the car, for example of its range.
  def day_chart?(sensor_name)
    @day_chart ||= {}
    @day_chart.fetch(sensor_name) do
      @day_chart[sensor_name] = Sensor::Registry[sensor_name].chart(Timeframe.new('day'), cars: [car], guest: false, admin: helpers.admin?).supported?
    end
  end
end
