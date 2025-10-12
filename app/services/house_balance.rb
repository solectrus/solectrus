# HouseBalance is a decorator that wraps Sensor::Data::Single objects to add
# house power validation and calculation methods.
#
# It provides house-specific validation logic like house_power_valid? to check
# if the house power consumption is reasonable compared to the sum of custom sensors.
#
# Usage:
#   data = Sensor::Data::Single.new(raw_data, timeframe:)
#   balance = HouseBalance.new(data)
#   balance.house_power_valid?  # Validates house power vs custom sensors
#
# All original sensor data methods are delegated to the wrapped object.
class HouseBalance
  include BalanceCustomPower

  def initialize(sensor_data)
    raise ArgumentError unless sensor_data.is_a?(Sensor::Data::Single)

    @sensor_data = sensor_data
    @memo = {}
  end

  # Check if house power value is valid (not less than sum of custom sensors)
  def house_power_valid?
    return true unless house_power # No validation if house_power is nil/empty

    house_power >= custom_power_total.to_f
  end

  # All possible custom power sensor names (1-20)
  CUSTOM_POWER_SENSOR_NAMES =
    (1..20).map { |i| :"custom_power_#{format('%02d', i)}" }.freeze
  private_constant :CUSTOM_POWER_SENSOR_NAMES

  # Define percentage methods for each custom power sensor
  CUSTOM_POWER_SENSOR_NAMES.each do |sensor_name|
    define_method(:"#{sensor_name}_percent") do
      custom_power_percent(sensor_name)
    end

    grid_sensor_name = :"#{sensor_name}_grid"
    define_method(:"#{sensor_name}_grid_ratio") do
      custom_power_grid_ratio(sensor_name, grid_sensor_name)
    end
  end

  # Percentage of house power without custom sensors vs total house power
  def house_power_without_custom_percent
    @memo[:house_power_without_custom_percent] ||= begin
      house_power_without_custom_value =
        if @sensor_data.respond_to?(:house_power_without_custom)
          @sensor_data.house_power_without_custom
        end

      if house_power_without_custom_value && house_power&.positive?
        house_power_without_custom_value.fdiv(house_power) * 100.0
      else
        0.0
      end
    end
  end

  def house_power_grid_ratio
    return unless respond_to?(:house_power) && respond_to?(:house_power_grid)
    return unless house_power&.positive?
    return unless house_power_grid

    (house_power_grid * 100.0 / house_power).round
  end

  private

  # Generic percent helper with memoization for custom power sensors
  # Calculates percentage of each custom sensor relative to total house power
  def custom_power_percent(sensor_name)
    @memo[:"#{sensor_name}_percent"] ||= begin
      sensor_value =
        if @sensor_data.respond_to?(sensor_name)
          @sensor_data.public_send(sensor_name)
        end

      if sensor_value && house_power&.positive?
        sensor_value.fdiv(house_power) * 100.0
      else
        0.0
      end
    end
  end

  # Explicitly delegate commonly used methods for performance
  delegate :house_power,
           :house_power_without_custom,
           :custom_power_total,
           :house_power_grid,
           :house_costs,
           :time,
           to: :@sensor_data

  # Delegate all other methods to the wrapped sensor data object
  delegate_missing_to :@sensor_data
end
