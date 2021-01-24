class Calculator::Base
  def build_context(hash)
    hash.each do |key, value|
      instance_variable_set(:"@#{key}", value)

      # TODO: Extract to new base class and define static methods
      define_singleton_method(key) do
        case key
        when :time
          instance_variable_get(:"@#{key}")
        when :bat_fuel_charge
          instance_variable_get(:"@#{key}").to_f
        else
          instance_variable_get(:"@#{key}").to_i
        end
      end
    end
  end

  def live?
    time && time > 10.seconds.ago
  end

  # Inverter

  def producing?
    inverter_power > 10
  end

  # Grid

  def feeding?
    return if grid_power < 50

    grid_power_minus > grid_power_plus
  end

  def grid_power_field
    feeding? ? 'grid_power_minus' : 'grid_power_plus'
  end

  def grid_power
    [ grid_power_plus, grid_power_minus ].compact.max
  end

  # House

  def consumption
    house_power + wallbox_charge_power
  end

  def grid_quote
    return 100.0 if consumption.zero?

    100.0 * grid_power_plus / consumption
  end

  def autarky
    100.0 - grid_quote
  end

  # Battery

  def bat_empty?
    bat_fuel_charge < 1
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
end
