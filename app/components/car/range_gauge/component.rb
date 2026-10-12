# The battery of the car as a gauge: an arc of 240 degrees from 0 to the
# maximum range, filled to the state of charge. The remaining range sits in
# the center. The block of the component stands right above the arc, the
# footer right below it, so both stay close to the arc.
class Car::RangeGauge::Component < ViewComponent::Base
  # The arc around (200, 175) with a radius of 150, open at the bottom
  ARC = 'M 70 250 A 150 150 0 1 1 330 250'.freeze
  public_constant :ARC

  # The plug and the charging power below the state of charge, in one badge
  SMALL_BADGE =
    'flex items-center rounded-full h-[clamp(2rem,9cqi,2.75rem)] ' \
    'bg-slate-100 dark:bg-slate-800'.freeze
  private_constant :SMALL_BADGE

  # The badge of the charging power while the wallbox charges, and else,
  # here and below the cars (see Car::LiveView::Component). Each sets the
  # color of the text, so a badge gets one of them alone.
  CHARGING_CLASSES = 'font-semibold text-slate-700 dark:text-slate-200'.freeze
  private_constant :CHARGING_CLASSES

  IDLE_CLASSES = 'text-slate-600 dark:text-slate-400'.freeze
  private_constant :IDLE_CLASSES

  def self.charging_classes(charging) = charging ? CHARGING_CLASSES : IDLE_CLASSES

  # A badge below the plug and the charging power, for example the place
  renders_one :location

  # The block below the arc, for example the odometer
  renders_one :footer

  # `state` holds the values of one car (see Car::Live::State)
  def initialize(state:)
    super()
    @state = state
  end

  attr_reader :state

  def soc
    state.soc&.clamp(0, 100)
  end

  delegate :range, :max_range, :charging_power, to: :state

  # The sensors with a value of their own in the state
  VALUES = { car_battery_soc: :soc, car_range: :range, car_odometer: :odometer }.freeze
  private_constant :VALUES

  # Whether the car has a range at all. A range without a current value
  # shows as a dash.
  def range? = sensor?(:car_range)

  # Whether the ends of the arc show the scale from 0 to the maximum range.
  # The maximum range needs the range and the state of charge.
  def scale? = sensor?(:car_max_range)

  # Whether a sensor of the car has no value, because it never reported. A
  # sensor without a configuration is no gap.
  def stale? = VALUES.any? { |role, value| sensor?(role) && state.public_send(value).nil? }

  # Whether the gauge shows the plug or the charging power
  def wallbox? = !state.connected.nil? || charging_power?

  # A car without a plug charges nothing, so its power of zero says nothing
  def charging_power? = !charging_power.nil? && state.connected != false

  def charging? = charging_power.to_f.positive?

  # The badge of the plug and the charging power. With the plug alone, the
  # badge is round.
  def wallbox_badge_classes
    class_names(
      SMALL_BADGE,
      charging_power? ? 'gap-2 px-[clamp(0.75rem,4cqi,1.25rem)] tabular-nums' : 'w-[clamp(2rem,9cqi,2.75rem)] justify-center',
      self.class.charging_classes(charging?),
    )
  end

  # The height that the arc leaves free: 1rem of room, and the height of the
  # block above (4rem, two lines like the name and the time) and of the
  # footer below (2.75rem), each with its gap of 1.5rem. A CSS variable keeps
  # the class of the width static for Tailwind.
  def reserve_style
    rem = (content? ? 5.5 : 0) + (footer? ? 4.25 : 0) + 1
    "--gauge-reserve: #{rem}rem"
  end

  # The sensor of this car with the given role, for its format
  def sensor_name(role)
    state.car.sensor_name(role)
  end

  def sensor?(role) = state.car.sensor?(role)

  # The fill of the arc in percent of its length, without a trailing ".0"
  def fill_percent
    format('%g', soc.round(1))
  end

  # The part of the arc that the charge fills next, in percent of its length
  CHARGING_SEGMENT = 8
  private_constant :CHARGING_SEGMENT

  # The length of the part that pulses while the car charges, or nil. A full
  # battery has no part left.
  def charging_segment
    return unless charging? && soc && soc < 100

    format('%g', [CHARGING_SEGMENT, 100 - soc].min.round(1))
  end

  # The arc is always blue (see --color-car-battery)
  ARC_CLASS = 'stroke-car-battery'.freeze
  public_constant :ARC_CLASS

  # The color of the badge for each level of the state of charge (see
  # Sensor::Definitions::CarBatterySoc.level): red, amber, then the blue of
  # the arc. The amber badge has dark text for contrast.
  # The class names stay literal, so Tailwind finds them.
  BADGE_CLASSES = {
    critical: 'bg-signal-negative text-white',
    low: 'bg-signal-warning text-slate-900',
    good: 'bg-car-battery text-white',
  }.freeze
  private_constant :BADGE_CLASSES

  def badge_class
    BADGE_CLASSES[Sensor::Definitions::CarBatterySoc.level(soc)]
  end
end
