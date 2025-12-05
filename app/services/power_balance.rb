# PowerBalance is a decorator that wraps Sensor::Data::Single objects to add
# power balance calculation methods (total_plus, total_minus, percentages).
#
# It groups power sensors into two categories:
# - PLUS: Sources of power (grid import, battery discharge, solar inverter)
# - MINUS: Consumers of power (grid export, battery charge, house, wallbox, heatpump)
#
# Usage:
#   data = Sensor::Data::Single.new(raw_data, timeframe:)
#   balance = PowerBalance.new(data)
#   balance.total_plus           # Sum of all power sources
#   balance.total_minus          # Sum of all power consumers
#   balance.inverter_power_percent  # Percentage of inverter power vs total_plus
#
# All original sensor data methods are delegated to the wrapped object.
class PowerBalance
  include BalanceCustomPower

  # ============================================================================
  # CONFIGURATION
  # ============================================================================

  PLUS_SENSOR_NAMES = %i[
    inverter_power
    battery_discharging_power
    grid_import_power
  ].freeze
  private_constant :PLUS_SENSOR_NAMES

  BASE_MINUS_SENSOR_NAMES = %i[
    house_power
    wallbox_power
    heatpump_power
    battery_charging_power
    grid_export_power
  ].freeze
  private_constant :BASE_MINUS_SENSOR_NAMES

  def self.minus_sensor_names
    Sensor::Config.house_power_excluded_custom_sensors.map(&:name) +
      BASE_MINUS_SENSOR_NAMES
  end

  # Define dynamic methods after Sensor::Config is initialized
  def self.define_dynamic_methods
    # Define percentage methods for each plus sensor
    PLUS_SENSOR_NAMES.each do |key|
      define_method(:"#{key}_percent") { percent(key, :plus) }
    end

    # Define percentage methods for each minus sensor (including custom sensors)
    minus_sensor_names.each do |key|
      define_method(:"#{key}_percent") { percent(key, :minus) }
    end

    # Define percentage methods for custom inverter sensors
    Sensor::Registry
      .all
      .grep(Sensor::Definitions::CustomInverterPower)
      .each do |sensor|
        define_method(:"#{sensor.name}_percent_of_total") do
          percent(sensor.name, :plus)
        end
      end

    # Define grid ratio methods for custom power sensors
    Sensor::Config.house_power_excluded_custom_sensors.each do |sensor|
      grid_sensor_name = :"#{sensor.name}_grid"
      define_method(:"#{sensor.name}_grid_ratio") do
        custom_power_grid_ratio(sensor.name, grid_sensor_name)
      end
    end
  end

  # ============================================================================
  # INITIALIZATION
  # ============================================================================

  def initialize(sensor_data)
    raise ArgumentError unless sensor_data.is_a?(Sensor::Data::Single)

    @sensor_data = sensor_data
    @memo = {}
  end

  # ============================================================================
  # CORE CALCULATIONS
  # ============================================================================

  def total_plus
    @memo[:total_plus] ||= sum_of(PLUS_SENSOR_NAMES)
  end

  def total_minus
    @memo[:total_minus] ||= sum_of(self.class.minus_sensor_names)
  end

  def total
    @memo[:total] ||= [total_minus, total_plus].max
  end

  # ============================================================================
  # PERCENTAGE CALCULATIONS
  # ============================================================================

  def battery_savings_percent
    return unless respond_to?(:savings) && respond_to?(:battery_savings)
    return unless savings&.positive?

    (battery_savings * 100.0 / savings).round
  end

  def forecast_deviation
    return unless respond_to?(:inverter_power_forecast)
    return unless inverter_power && inverter_power_forecast

    actual = inverter_power.to_f
    forecast = inverter_power_forecast.to_f
    return 0 if forecast.zero?

    ((actual - forecast) / forecast * 100).round
  end

  # ============================================================================
  # GRID RATIO CALCULATIONS
  # ============================================================================

  def wallbox_power_grid_ratio
    grid_ratio(:wallbox_power, :wallbox_power_grid)
  end

  def house_power_grid_ratio
    grid_ratio(:house_power, :house_power_grid)
  end

  def heatpump_power_grid_ratio
    grid_ratio(:heatpump_power, :heatpump_power_grid)
  end

  def battery_charging_power_grid_ratio
    grid_ratio(:battery_charging_power, :battery_charging_power_grid)
  end

  # ============================================================================
  # VALIDATION
  # ============================================================================

  def valid_multi_inverter?
    @valid_multi_inverter ||=
      inverter_power.nil? ||
        begin
          respond_to?(:inverter_power_total) && inverter_power_total.present? &&
            !inverter_power.zero? &&
            (inverter_power_total.fdiv(inverter_power) * 100.0).round >= 99
        end
  end

  # ============================================================================
  # DELEGATION
  # ============================================================================

  # Explicit delegation for the hot path (avoids method_missing for these).
  delegate(*PLUS_SENSOR_NAMES, *BASE_MINUS_SENSOR_NAMES, to: :@sensor_data)

  # Delegate the rest without per-call respond_to? checks.
  delegate_missing_to :@sensor_data

  private

  # ============================================================================
  # PRIVATE HELPERS
  # ============================================================================

  def sum_of(sensor_names)
    sensor_names.sum { @sensor_data.public_send(it).to_f }
  end

  def percent(sensor_name, side)
    @memo[:"#{sensor_name}_percent"] ||= begin
      part = @sensor_data.public_send(sensor_name)
      if part
        whole = side == :plus ? total_plus : total_minus
        whole.zero? ? 0.0 : part.fdiv(whole) * 100.0
      else
        0
      end
    end
  end

  def grid_ratio(power_sensor, grid_sensor)
    return unless respond_to?(power_sensor) && respond_to?(grid_sensor)

    power = public_send(power_sensor)
    grid = public_send(grid_sensor)

    return unless power&.positive? && grid

    (grid * 100.0 / power).clamp(0, 100).round
  end
end

# ============================================================================
# INITIALIZE DYNAMIC METHODS
# ============================================================================

Rails.application.config.after_initialize do
  PowerBalance.define_dynamic_methods
end

if Rails.env.development?
  Rails.application.reloader.to_prepare { PowerBalance.define_dynamic_methods }
end
