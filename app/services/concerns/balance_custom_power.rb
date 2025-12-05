# Shared functionality for custom power sensor grid ratio calculations
# used by balance decorators that wrap Sensor::Data::Single objects.
module BalanceCustomPower
  extend ActiveSupport::Concern

  private

  # Grid ratio helper for custom power sensors
  # Calculates percentage of grid power vs total power for each custom sensor
  def custom_power_grid_ratio(sensor_name, grid_sensor_name)
    @memo["#{sensor_name}_grid_ratio"] ||= calculate_custom_power_grid_ratio(
      sensor_name,
      grid_sensor_name,
    )
  end

  def calculate_custom_power_grid_ratio(sensor_name, grid_sensor_name)
    unless @sensor_data.respond_to?(sensor_name) &&
             @sensor_data.respond_to?(grid_sensor_name)
      return
    end

    total_power = @sensor_data.public_send(sensor_name)
    grid_power = @sensor_data.public_send(grid_sensor_name)

    return unless total_power&.positive?
    return unless grid_power

    (grid_power * 100.0 / total_power).clamp(0, 100).round
  end
end
