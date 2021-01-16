class BaseCalculator
  def build_context(hash)
    hash.each do |key, value|
      instance_variable_set(:"@#{key}", value)

      define_singleton_method(key) do
        instance_variable_get(:"@#{key}")
      end
    end
  end

  delegate :present?, :blank?, to: :time

  def live?
    present? && time > 10.seconds.ago
  end

  def bat_charging?
    return unless bat_power_plus && bat_power_minus

    bat_power_plus > bat_power_minus
  end

  def bat_power
    [ bat_power_plus, bat_power_minus ].compact.max
  end

  def bat_power_field
    bat_charging? ? 'bat_power_plus' : 'bat_power_minus'
  end

  def producing?
    inverter_power.to_f > 2
  end

  def feeding?
    return unless grid_power_plus && grid_power_minus

    grid_power_minus > grid_power_plus
  end

  def grid_power
    [ grid_power_plus, grid_power_minus ].compact.max
  end

  def grid_power_field
    feeding? ? 'grid_power_minus' : 'grid_power_plus'
  end

  def consumption
    house_power.to_f + wallbox_charge_power.to_f
  end

  def grid_quote
    return 100 if consumption.zero?

    100 * grid_power_plus / consumption
  end

  def autarky
    100 - grid_quote
  end
end
