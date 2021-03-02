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

  POWER_FIELDS = FIELDS.select { |field| field.include?('power') }
end
