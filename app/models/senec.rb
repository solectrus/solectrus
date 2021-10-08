module Senec
  FIELDS = %w[
    inverter_power
    house_power
    grid_power_plus
    grid_power_minus
    bat_power_minus
    bat_power_plus
    bat_fuel_charge
    wallbox_charge_power
  ].freeze

  # All fields related to power (= all but bat_fuel_charge)
  POWER_FIELDS = FIELDS.select { |field| field.include?('power') }.freeze

  # Combine plus/minus fields, e.g. `grid_power` instead of `grid_power_plus` and `grid_power_minus`
  POWER_FIELDS_COMBINED =
    POWER_FIELDS.map { |field| field.gsub(/_plus|_minus/, '') }.uniq.freeze
end
