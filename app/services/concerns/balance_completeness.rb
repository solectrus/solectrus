# Compares the two sides of the power balance for balance decorators that wrap
# Sensor::Data::Single objects. Sources and sinks describe the same energy, so
# what is left over says something about how completely it was recorded.
module BalanceCompleteness
  extend ActiveSupport::Concern

  # Sensors that must carry a value before sources and sinks can be compared at
  # all. Without one of them the rest says nothing about missing consumers,
  # because a whole side of the balance is absent.
  CORE_SENSOR_NAMES = %i[
    inverter_power
    grid_import_power
    grid_export_power
    house_power
  ].freeze
  private_constant :CORE_SENSOR_NAMES

  # Any of these means the installation has a battery, and a battery moves
  # energy through the balance in both directions.
  BATTERY_SENSOR_NAMES = %i[
    battery_soc
    battery_charging_power
    battery_discharging_power
  ].freeze
  private_constant :BATTERY_SENSOR_NAMES

  BATTERY_FLOW_SENSOR_NAMES = %i[
    battery_charging_power
    battery_discharging_power
  ].freeze
  private_constant :BATTERY_FLOW_SENSOR_NAMES

  # Below this share of the incoming energy the rest is measurement noise, not
  # a sensor that misses or double counts something. The limit is the same in
  # both directions, because a difference is a defect in both.
  #
  # Measured against 2110 days of a well instrumented installation with a
  # battery: a day reaches the limit about 6 times a year, a week twice in the
  # whole record, a month and a year never. Most of those days are battery
  # losses, which the explanation names.
  THRESHOLD_PERCENT = 5
  private_constant :THRESHOLD_PERCENT

  # What the sources deliver beyond what the sinks account for. A positive rest
  # means consumption is recorded incompletely -- a consumer without its own
  # sensor, or one that its parent sensor already subtracts.
  #
  # A negative rest means the opposite: a consumption is counted twice, or a
  # source is missing. Battery losses land here as well, because charging is a
  # sink and discharging a source, so what the battery keeps for itself never
  # returns. The state of charge itself does not belong here -- it sits outside
  # the balance, and both of its flows already cross it.
  def imbalance
    return unless imbalance_available?

    total_plus - total_minus
  end

  # The rest against the side it came from, so the reader can do the same sum
  # with the two numbers the sign itself shows.
  def imbalance_percent
    rest = imbalance
    return if rest.nil? || total_plus.zero?

    rest * 100.0 / total_plus
  end

  # Whether the rest is big enough to tell the user about. Both directions
  # matter: a surplus of sources means consumption is recorded incompletely, a
  # surplus of sinks means it is recorded twice or a source is missing. Either
  # way every number derived from the consumption is off.
  def imbalance_relevant?
    percent = imbalance_percent
    return false unless percent

    percent.abs >= THRESHOLD_PERCENT
  end

  # Whether the installation has a battery, which decides how the rest may be
  # read: only a battery loses energy inside the balance.
  def battery?
    BATTERY_SENSOR_NAMES.any? { Sensor::Config.configured?(it) }
  end

  private

  # #total_plus and #total_minus raise as soon as one of their sensors was not
  # queried, so both sides must be complete before they may be compared.
  def imbalance_available?
    queried = @sensor_data.sensor_names
    both_sides = self.class.minus_sensor_names + self.class.plus_sensor_names
    return false unless both_sides.all? { queried.include?(it) }
    return false unless CORE_SENSOR_NAMES.all? { imbalance_sensor_value?(it) }

    # A battery that charges without reporting how much looks exactly like a
    # missing consumer: the sources exceed the sinks. Both of its flows must be
    # known before the rest may be read as anything.
    return true unless battery?

    BATTERY_FLOW_SENSOR_NAMES.all? { imbalance_sensor_value?(it) }
  end

  def imbalance_sensor_value?(sensor_name)
    !@sensor_data.public_send(sensor_name).nil?
  end
end
