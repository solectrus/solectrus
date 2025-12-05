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

  # Percentage of total house power consumption supplied from grid
  def house_power_grid_ratio
    return unless respond_to?(:house_power) && respond_to?(:house_power_grid)
    return unless house_power&.positive?
    return unless house_power_grid

    (house_power_grid * 100.0 / house_power).clamp(0, 100).round
  end

  # Total grid power from all custom power sensors
  # Sums up grid consumption for custom_power_01_grid through custom_power_20_grid
  def custom_power_grid_total
    @memo[
      :custom_power_grid_total # rubocop:disable Style/TrailingCommaInArguments
    ] ||= CUSTOM_POWER_SENSOR_NAMES.sum do |sensor_name|
      grid_sensor_name = :"#{sensor_name}_grid"
      if @sensor_data.respond_to?(grid_sensor_name)
        @sensor_data.public_send(grid_sensor_name).to_f
      else
        0
      end
    end
  end

  # Grid power consumption for "other consumers" (house without custom sensors)
  def house_power_without_custom_grid
    return unless house_power_grid

    house_power_grid - custom_power_grid_total
  end

  # Percentage of "other consumers" power supplied from grid
  # Returns rounded percentage (0-100) showing how much of the power for
  # "other consumers" (house without custom sensors) comes from the grid
  def house_power_without_custom_grid_ratio
    return unless house_power_without_custom_grid
    return unless house_power_without_custom&.positive?

    (house_power_without_custom_grid * 100.0 / house_power_without_custom).clamp(0, 100).round
  end

  # Grid costs for "other consumers" (house without custom sensors)
  # Calculated proportionally: house_power_without_custom / house_power * house_costs_grid
  # This ensures consistency with house_without_custom_costs calculation
  def house_without_custom_costs_grid
    return unless respond_to?(:house_costs_grid) && house_costs_grid
    return unless house_power&.positive? && house_power_without_custom

    @memo[:house_without_custom_costs_grid] ||=
      house_power_without_custom / house_power * house_costs_grid
  end

  # Opportunity costs for "other consumers" (house without custom sensors)
  # Calculated proportionally: house_power_without_custom / house_power * house_costs_pv
  # This ensures consistency with house_without_custom_costs calculation
  def house_without_custom_costs_pv
    return unless respond_to?(:house_costs_pv) && house_costs_pv
    return unless house_power&.positive? && house_power_without_custom

    @memo[:house_without_custom_costs_pv] ||=
      house_power_without_custom / house_power * house_costs_pv
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
