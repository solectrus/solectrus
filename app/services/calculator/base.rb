class Calculator::Base
  def build_method(key, data = nil, modifier = nil, &)
    if data.nil? ^ block_given?
      raise ArgumentError, 'Either data or block must be given, not both'
    end

    define_singleton_method(key) do
      result = (data ? data[key] : yield)
      result = result.public_send(modifier) if modifier
      result
    end
  end

  def build_method_from_array(key, data, modifier = nil)
    values =
      if modifier
        data.pluck(key).map { |value| value.public_send(modifier) }
      else
        data.pluck(key)
      end

    build_method("#{key}_array") { values }
    build_method(key) { values.sum }
  end

  # Inverter

  def producing?
    return unless inverter_power

    inverter_power >= 50
  end

  def inverter_power_percent
    return unless inverter_power && total_plus
    return 0 if total_plus.zero?

    (inverter_power * 100.0 / total_plus).round(1)
  end

  # Grid

  def feeding?
    return unless grid_power_plus && grid_power_minus
    return false if [grid_power_plus, grid_power_minus].compact.max < 50

    grid_power_minus > grid_power_plus
  end

  def grid_power
    return unless grid_power_plus && grid_power_minus

    feeding? ? grid_power_minus : -grid_power_plus
  end

  def grid_power_plus_percent
    return unless grid_power_plus && total_plus
    return 0 if total_plus.zero?

    (grid_power_plus * 100.0 / total_plus).round(1)
  end

  def grid_power_minus_percent
    return unless grid_power_minus && total_minus
    return 0 if total_minus.zero?

    (grid_power_minus * 100.0 / total_minus).round(1)
  end

  # House

  def consumption
    return unless house_power && wallbox_charge_power

    house_power + wallbox_charge_power
  end

  def consumption_array
    sections.each_with_index.map do |_section, index|
      house_power_array[index] + wallbox_charge_power_array[index]
    end
  end

  def consumption_alt
    return unless inverter_power && grid_power_minus

    inverter_power - grid_power_minus
  end

  def consumption_quote
    return unless consumption_alt && inverter_power
    return if inverter_power < 50

    [consumption_alt * 100.0 / inverter_power, 0.0].max.round(1)
  end

  def grid_quote
    return unless consumption && grid_power_plus

    if consumption.zero?
      # Producing without any consumption
      #  => Maybe there is a balkony power plant
      #  => 0% grid quote
      return 0 if producing?

      # No consumption and no production => nil
      return
    end

    [grid_power_plus * 100.0 / consumption, 100].min
  end

  def autarky
    return unless grid_quote

    (100.0 - grid_quote).round(1)
  end

  def house_power_percent
    return unless house_power && total_minus
    return 0 if total_minus.zero?

    (house_power * 100.0 / total_minus).round(1)
  end

  # Wallbox

  def wallbox_charge_power_percent
    return unless wallbox_charge_power && total_minus
    return 0 if total_minus.zero?

    (wallbox_charge_power * 100.0 / total_minus).round(1)
  end

  # Battery

  def bat_charging?
    return unless bat_power_plus && bat_power_minus

    bat_power_plus > bat_power_minus
  end

  def bat_power
    return unless bat_power_plus && bat_power_minus

    bat_charging? ? bat_power_plus : -bat_power_minus
  end

  def bat_power_minus_percent
    return unless bat_power_minus && total_plus
    return 0 if total_plus.zero?

    (bat_power_minus * 100.0 / total_plus).round(1)
  end

  def bat_power_plus_percent
    return unless bat_power_plus && total_minus
    return 0 if total_minus.zero?

    (bat_power_plus * 100.0 / total_minus).round(1)
  end

  # Total

  def total_plus
    return unless grid_power_plus && bat_power_minus && inverter_power

    grid_power_plus + bat_power_minus + inverter_power
  end

  def total_minus
    unless grid_power_minus && bat_power_plus && house_power &&
             wallbox_charge_power
      return
    end

    grid_power_minus + bat_power_plus + house_power + wallbox_charge_power
  end

  def total
    [total_minus, total_plus].compact.max
  end
end
