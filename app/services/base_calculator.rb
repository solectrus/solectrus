class BaseCalculator # rubocop:disable Metrics/ClassLength
  def build_context(hash)
    hash.each do |key, value|
      instance_variable_set(:"@#{key}", value)

      define_singleton_method(key) do
        if key == :time
          instance_variable_get(:"@#{key}")
        else
          instance_variable_get(:"@#{key}").to_f
        end
      end
    end
  end

  delegate :present?, :blank?, to: :time

  def live?
    present? && time > 10.seconds.ago
  end

  def bat_charging?
    bat_power_plus > bat_power_minus
  end

  def bat_power
    [ bat_power_plus, bat_power_minus ].max
  end

  def bat_power_field
    bat_charging? ? 'bat_power_plus' : 'bat_power_minus'
  end

  def bat_empty?
    bat_fuel_charge < 1
  end

  def producing?
    inverter_power > 2
  end

  def feeding?
    return if grid_power < 50

    grid_power_minus > grid_power_plus
  end

  def grid_power
    [ grid_power_plus, grid_power_minus ].compact.max
  end

  def grid_power_field
    feeding? ? 'grid_power_minus' : 'grid_power_plus'
  end

  def consumption
    house_power + wallbox_charge_power
  end

  def grid_quote
    return 100 if consumption.zero?

    100.0 * grid_power_plus / consumption
  end

  def autarky
    100 - grid_quote.round
  end

  def inverter_to_wallbox
    if producing? && wallbox_charge_power.positive?
      inverter_power
    else
      0
    end
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

  def grid_to_wallbox
    if wallbox_charge_power&.positive?
      grid_power_plus - grid_to_house
    else
      0
    end
  end

  def grid_to_house
    grid_power_plus
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
