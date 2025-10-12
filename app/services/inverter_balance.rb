# InverterBalance is a decorator that wraps Sensor::Data::Single objects to add
# inverter balance calculation methods (total, percentages).
#
# Usage:
#   data = Sensor::Data::Single.new(raw_data, timeframe:)
#   balance = InverterBalance.new(data)
#   balance.inverter_power_percent  # Percentage of inverter power vs total
#
# All original sensor data methods are delegated to the wrapped object.
class InverterBalance
  def initialize(sensor_data)
    raise ArgumentError unless sensor_data.is_a?(Sensor::Data::Single)

    @sensor_data = sensor_data
    @memo = {}
  end

  # Define percentage methods for each custom inverter
  Sensor::Registry
    .all
    .grep(Sensor::Definitions::CustomInverterPower)
    .each do |sensor|
      define_method(:"#{sensor.name}_percent") { percent(sensor.name) }

      # def inverter_power_1_percent
      #   percent(:inverter_power_1, :plus)
      # end
    end

  # Delegate the rest without per-call respond_to? checks.
  delegate_missing_to :@sensor_data

  # Is the sum of the individual inverter power
  # equal to the total power of the inverter?
  def valid_multi_inverter?
    @valid_multi_inverter ||=
      inverter_power.nil? ||
        begin
          inverter_power_total.present? && !inverter_power.zero? &&
            (inverter_power_total.fdiv(inverter_power) * 100.0).round >= 99
        end
  end

  def inverter_power_difference_percent
    return unless inverter_power_difference
    return if inverter_power.zero?

    (inverter_power_difference * 100.0 / inverter_power).round(1)
  end

  def inverter_power_sum
    return @inverter_power_sum if defined?(@inverter_power_sum)

    @inverter_power_sum =
      Sensor::Config
        .custom_inverter_sensors
        .filter_map { |sensor| public_send(sensor.name) }
        .presence
        &.sum
  end

  private

  def sum_of(sensor_names)
    sensor_names.sum { @sensor_data.public_send(it).to_f }
  end

  # Generic percent helper with memoization.
  def percent(sensor_name)
    @memo[:"#{sensor_name}_percent"] ||= begin
      part = @sensor_data.public_send(sensor_name)

      if part.nil? || inverter_power.nil? || inverter_power.zero?
        0.0
      else
        (part.fdiv(inverter_power) * 100.0).round(1)
      end
    end
  end
end
