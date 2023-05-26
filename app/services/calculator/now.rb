class Calculator::Now < Calculator::Base
  def initialize
    super

    build_context PowerSum.new(
                    measurements: [Rails.configuration.x.influx.measurement_pv],
                    fields: %i[
                      current_state
                      inverter_power
                      house_power
                      wallbox_charge_power
                      grid_power_plus
                      grid_power_minus
                      bat_power_minus
                      bat_power_plus
                      bat_fuel_charge
                      case_temp
                    ],
                  ).call(Timeframe.now)
  end

  def inverter_to_house
    [
      inverter_power - inverter_to_battery - inverter_to_wallbox,
      house_power,
    ].min
  end

  def inverter_to_battery
    bat_charging? && inverter_power >= bat_power_plus ? bat_power_plus : 0
  end

  def inverter_to_wallbox
    producing? && wallbox_charge_power.positive? ? inverter_power : 0
  end

  def grid_to_house
    [house_power - inverter_to_house - battery_to_house, 0].max
  end

  def grid_to_wallbox
    wallbox_charge_power&.positive? ? grid_power_plus - grid_to_house : 0
  end

  def battery_to_house
    bat_empty? ? 0 : bat_power_minus
  end

  def grid_to_battery
    if bat_charging? && grid_power_plus > (house_power + wallbox_charge_power)
      bat_power_plus
    else
      0
    end
  end

  def house_to_grid
    feeding? ? grid_power_minus : 0
  end
end
