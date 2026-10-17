# The values of the battery of a car as the live view shows them, shared by
# the gauge and the bar (see Car::RangeGauge::Component and
# Car::RangeBar::Component). The component needs a `state` (see
# Car::Live::State).
module Car::BatteryDisplay
  # The badge of the charging power while the wallbox charges, and else,
  # in the gauge, in the bar and below the cars (see Car::LiveView::Component).
  # Each sets the color of the text, so a badge gets one of them alone.
  CHARGING_CLASSES = 'font-semibold text-slate-700 dark:text-slate-200'.freeze
  private_constant :CHARGING_CLASSES

  IDLE_CLASSES = 'text-slate-600 dark:text-slate-400'.freeze
  private_constant :IDLE_CLASSES

  def self.charging_classes(charging) = charging ? CHARGING_CLASSES : IDLE_CLASSES

  # The sensors with a value of their own in the state
  VALUES = { car_battery_soc: :soc, car_range: :range, car_odometer: :odometer }.freeze
  private_constant :VALUES

  # The part of the battery that the charge fills next, in percent
  CHARGING_SEGMENT = 8
  private_constant :CHARGING_SEGMENT

  # The color of the badge for each level of the state of charge (see
  # Sensor::Definitions::CarBatterySoc.level): red, yellow, then the blue of
  # the battery. The yellow is lighter than the warning signal, so it reads
  # as yellow, and it has dark text for contrast.
  # The class names stay literal, so Tailwind finds them.
  BADGE_CLASSES = {
    critical: 'bg-signal-negative text-white',
    low: 'bg-amber-400 text-slate-900',
    good: 'bg-car-battery text-white',
  }.freeze
  private_constant :BADGE_CLASSES

  def soc
    state.soc&.clamp(0, 100)
  end

  delegate :range, :max_range, :charging_power, to: :state

  # Whether the car has a range at all, from its sensor or estimated. A
  # range sensor without a current value shows as a dash. Without both, the
  # state of charge takes the place of the range.
  def range? = sensor?(:car_range) || !range.nil?

  # Whether the range is an estimate (see Car::RangeEstimate), which its
  # label names
  def estimated? = !sensor?(:car_range) && !range.nil?

  # Whether the ends show the scale from 0 to the maximum range. The maximum
  # range needs the range and the state of charge, or the estimate.
  def scale? = sensor?(:car_max_range) || !max_range.nil?

  # Whether a sensor of the car has no value, because it never reported. A
  # sensor without a configuration is no gap.
  def stale? = VALUES.any? { |role, value| sensor?(role) && state.public_send(value).nil? }

  # Whether the component shows the plug or the charging power
  def wallbox? = !state.connected.nil? || charging_power?

  # A car without a plug charges nothing, so its power of zero says nothing
  def charging_power? = !charging_power.nil? && state.connected != false

  def charging? = charging_power.to_f.positive?

  # The sensor of this car with the given role, for its format
  def sensor_name(role)
    state.car.sensor_name(role)
  end

  # A state without a car is the frame of the live view while no car is in
  # use (see Car::LiveView::Component), so it has no sensor
  def sensor?(role)
    @sensor ||= {}
    @sensor.fetch(role) { @sensor[role] = state.car&.sensor?(role) || false }
  end

  # The fill in percent of the length, without a trailing ".0"
  def fill_percent
    format('%g', soc.round(1))
  end

  # The length of the part that pulses while the car charges, in percent of
  # the length, or nil. A full battery has no part left.
  def charging_segment
    return unless charging? && soc && soc < 100

    format('%g', [CHARGING_SEGMENT, 100 - soc].min.round(1))
  end

  def badge_class
    BADGE_CLASSES[Sensor::Definitions::CarBatterySoc.level(soc)]
  end
end
