class Calculator::Base
  def build_context(hash_or_array)
    case hash_or_array
    when Array
      array = hash_or_array
      hash = array.first
    when Hash
      array = [hash_or_array]
      hash = hash_or_array
    else
      # :nocov:
      raise ArgumentError, 'Argument must be Hash or Array'
      # :nocov:
    end

    # TODO: Extract to new base class and define static methods
    hash.each_key do |key|
      case key
      when :time, :current_state, :current_state_ok, :power_ratio
        value = array.pluck(key).last

        define_singleton_method(key) { value }
      when :feed_in_tariff, :electricity_price
        values = array.pluck(key)

        define_singleton_method(key) { values }
      else
        values = array.map { |v| v[key].to_f }

        define_singleton_method(key) { values.sum }
        define_singleton_method("#{key}_array") { values }
      end
    end

    define_singleton_method(:sections) { array }
  end

  # Inverter

  def producing?
    inverter_power >= 50
  end

  def inverter_power_percent
    return 0 if total_plus.zero?

    (inverter_power * 100.0 / total_plus).round(1)
  end

  # Grid

  def feeding?
    return false if [grid_power_plus, grid_power_minus].compact.max < 50

    grid_power_minus > grid_power_plus
  end

  def grid_power
    feeding? ? grid_power_minus : -grid_power_plus
  end

  def grid_power_plus_percent
    return 0 if total_plus.zero?

    (grid_power_plus * 100.0 / total_plus).round(1)
  end

  def grid_power_minus_percent
    return 0 if total_minus.zero?

    (grid_power_minus * 100.0 / total_minus).round(1)
  end

  # House

  def consumption
    house_power + wallbox_charge_power
  end

  def consumption_array
    sections.each_with_index.map do |_section, index|
      house_power_array[index] + wallbox_charge_power_array[index]
    end
  end

  def consumption_alt
    inverter_power - grid_power_minus
  end

  def consumption_quote
    return if inverter_power < 50

    [consumption_alt * 100.0 / inverter_power, 0.0].max.round(1)
  end

  def grid_quote
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
    return 0 if total_minus.zero?

    (house_power * 100.0 / total_minus).round(1)
  end

  # Wallbox

  def wallbox_charge_power_percent
    return 0 if total_minus.zero?

    (wallbox_charge_power * 100.0 / total_minus).round(1)
  end

  # Battery

  def bat_empty?
    bat_fuel_charge < 1
  end

  def bat_charging?
    bat_power_plus > bat_power_minus
  end

  def bat_power
    bat_charging? ? bat_power_plus : -bat_power_minus
  end

  def bat_power_minus_percent
    return 0 if total_plus.zero?

    (bat_power_minus * 100.0 / total_plus).round(1)
  end

  def bat_power_plus_percent
    return 0 if total_minus.zero?

    (bat_power_plus * 100.0 / total_minus).round(1)
  end

  # Total

  def total_plus
    grid_power_plus + bat_power_minus + inverter_power
  end

  def total_minus
    grid_power_minus + bat_power_plus + house_power + wallbox_charge_power
  end

  def total
    [total_minus, total_plus].max
  end
end
