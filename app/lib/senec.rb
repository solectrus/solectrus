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
    case_temp
  ].freeze
  public_constant :FIELDS

  CALCULATED_FIELDS = %w[autarky consumption].freeze
  public_constant :CALCULATED_FIELDS

  # All fields related to power (= all but `bat_fuel_charge`)
  POWER_FIELDS = FIELDS.select { |field| field.include?('power') }.freeze
  public_constant :POWER_FIELDS

  # Combine plus/minus fields, e.g. `grid_power` instead of `grid_power_plus` and `grid_power_minus`
  FIELDS_COMBINED =
    (
      FIELDS.map { |field| field.gsub(/_plus|_minus/, '') } + CALCULATED_FIELDS
    ).uniq.freeze
  public_constant :FIELDS_COMBINED
end
