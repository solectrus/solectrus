# HeatpumpBalance is a decorator that wraps Sensor::Data::Single objects to add
# heatpump-specific calculation methods.
#
# It provides heatpump power distribution analysis:
# - Total heatpump power vs heating power
# - Environmental energy calculation
# - PV vs Grid power distribution
#
# Usage:
#   data = Sensor::Data::Single.new(raw_data, timeframe:)
#   balance = HeatpumpBalance.new(data)
#   balance.heatpump_power_percent_heating  # Percent of total power used for heating
#
# All original sensor data methods are delegated to the wrapped object.
class HeatpumpBalance
  def initialize(sensor_data)
    raise ArgumentError unless sensor_data.is_a?(Sensor::Data::Single)

    @sensor_data = sensor_data
    @memo = {}
  end

  # Delegate all sensor data methods to the wrapped object
  delegate_missing_to :@sensor_data

  # Percentage of heating power from electrical power vs environmental energy
  def heatpump_power_percent_heating
    @memo[:heatpump_power_percent_heating] ||= calculate_power_percentage(
      heatpump_heating_power,
      heatpump_power,
    )
  end

  # Percentage of environmental energy vs total heating power
  def heatpump_power_env_percent
    @memo[:heatpump_power_env_percent] ||= calculate_power_source_percentage(
      :heatpump_power_env,
    )
  end

  # Percentage of PV power vs total heating power
  def heatpump_power_pv_percent
    @memo[:heatpump_power_pv_percent] ||= calculate_power_source_percentage(
      :heatpump_power_pv,
    )
  end

  # Percentage of grid power vs total heating power
  def heatpump_power_grid_percent
    @memo[:heatpump_power_grid_percent] ||= calculate_power_source_percentage(
      :heatpump_power_grid,
    )
  end

  private

  def calculate_power_percentage(heating_power, electrical_power)
    return 0 unless heating_power&.positive? && electrical_power&.positive?

    electrical_power.fdiv(heating_power) * 100.0
  end

  def calculate_power_source_percentage(source_method)
    return 0 unless heatpump_heating_power&.positive?
    return 0 unless respond_to?(source_method)

    source_power = public_send(source_method)
    return 0 unless source_power&.positive?

    source_power.fdiv(heatpump_heating_power) * 100.0
  end
end
