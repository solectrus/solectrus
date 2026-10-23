# The values of the battery of a car as the live view shows them (see
# Car::LiveCard::Component). The component needs a `state` (see
# Car::Live::State).
module Car::BatteryDisplay
  # The sensors with a value of their own in the state
  VALUES = { car_battery_soc: :soc, car_range: :range, car_odometer: :odometer }.freeze
  private_constant :VALUES

  # The part of the battery that the charge fills next, in percent
  CHARGING_SEGMENT = 8
  private_constant :CHARGING_SEGMENT

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

  def charging? = charging_power.to_f.positive?

  # The sensor of this car with the given role, for its format
  def sensor_name(role)
    state.car.sensor_name(role)
  end

  def sensor?(role)
    @sensor ||= {}
    @sensor.fetch(role) { @sensor[role] = state.car.sensor?(role) }
  end

  # The fill in percent of the length, without a trailing ".0"
  def fill_percent
    format('%g', soc.round(1))
  end

  # The end of the part that pulses while the car charges, in percent of the
  # length, or nil. A full battery has no part left.
  def charging_percent
    return unless charging? && soc && soc < 100

    format('%g', [soc + CHARGING_SEGMENT, 100].min.round(1))
  end
end
