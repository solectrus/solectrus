class Calculator::Now < Calculator::Base
  def initialize
    super

    build_context PowerSum.new(
      :inverter_power,
      :house_power,
      :wallbox_charge_power,
      :grid_power_plus,
      :grid_power_minus,
      :bat_power_minus,
      :bat_power_plus,
      :bat_fuel_charge
    ).now
  end

  def inverter_to_house
    if producing?
      [ house_power, inverter_power ].min
    else
      0
    end
  end

  def inverter_to_battery
    if bat_charging?
      inverter_power - house_power
    else
      0
    end
  end

  def inverter_to_wallbox
    if producing? && wallbox_charge_power.positive?
      inverter_power
    else
      0
    end
  end

  def grid_to_house
    grid_power_plus
  end

  def grid_to_wallbox
    if wallbox_charge_power&.positive?
      grid_power_plus - grid_to_house
    else
      0
    end
  end

  def battery_to_house
    if bat_empty?
      0
    else
      bat_power_minus
    end
  end

  def grid_to_battery
    if bat_charging? && grid_power_plus > (house_power + wallbox_charge_power)
      bat_power_plus
    else
      0
    end
  end

  def house_to_grid
    if feeding?
      grid_power_minus
    else
      0
    end
  end
end
