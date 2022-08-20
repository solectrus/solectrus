class Calculator::Base
  def build_context(hash_or_array) # rubocop:disable Metrics/CyclomaticComplexity
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
      when :time
        value = array.map { |v| v[key] }.last

        define_singleton_method(key) { value }
      when :feed_in_tariff, :electricity_price
        values = array.map { |v| v[key] }

        define_singleton_method(key) { values }
      else
        values = array.map { |v| v[key].to_f }

        define_singleton_method(key) { values.sum }
        define_singleton_method("#{key}_array") { values }
      end
    end

    define_singleton_method(:sections) { array }
  end

  def live?
    time && time > 10.seconds.ago
  end

  # Inverter

  def producing?
    inverter_power >= 50
  end

  # Grid

  def feeding?
    return if [grid_power_plus, grid_power_minus].compact.max < 50

    grid_power_minus > grid_power_plus
  end

  def grid_power
    feeding? ? grid_power_minus : -grid_power_plus
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

  def grid_quote
    return if consumption.zero?

    [100.0 * grid_power_plus / consumption, 100].min
  end

  def autarky
    return unless grid_quote

    (100.0 - grid_quote).round(1)
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
end
