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
    build_method(key) { values.compact.sum }
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
    return unless grid_import_power && grid_export_power
    return false if [grid_import_power, grid_export_power].compact.max < 50

    grid_export_power > grid_import_power
  end

  def grid_power
    return unless grid_import_power && grid_export_power

    feeding? ? grid_export_power : -grid_import_power
  end

  def grid_import_power_percent
    return unless grid_import_power && total_plus
    return 0 if total_plus.zero?

    (grid_import_power * 100.0 / total_plus).round(1)
  end

  def grid_export_power_percent
    return unless grid_export_power && total_minus
    return 0 if total_minus.zero?

    (grid_export_power * 100.0 / total_minus).round(1)
  end

  # House

  def consumption
    return unless house_power && wallbox_power

    house_power + wallbox_power + heatpump_power.to_f
  end

  def consumption_array
    sections.each_with_index.map do |_section, index|
      house_power_array[index] + wallbox_power_array[index] +
        heatpump_power_array[index]
    end
  end

  def consumption_alt
    return unless inverter_power && grid_export_power

    inverter_power - grid_export_power
  end

  def consumption_quote
    return unless consumption_alt && inverter_power
    return if inverter_power < 50

    [consumption_alt * 100.0 / inverter_power, 0.0].max.round(1)
  end

  def grid_quote
    return unless consumption && grid_import_power

    if consumption.zero?
      # Producing without any consumption
      #  => Maybe there is a balkony heatpump_power plant
      #  => 0% grid quote
      return 0 if producing?

      # No consumption and no production => nil
      return
    end

    [grid_import_power * 100.0 / consumption, 100].min
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

  def heatpump_power_percent
    return unless heatpump_power && total_minus
    return 0 if total_minus.zero?

    (heatpump_power * 100.0 / total_minus).round(1)
  end

  # Wallbox

  def wallbox_power_percent
    return unless wallbox_power && total_minus
    return 0 if total_minus.zero?

    (wallbox_power * 100.0 / total_minus).round(1)
  end

  # Battery

  def bat_charging?
    return unless battery_charging_power && battery_discharging_power

    battery_charging_power > battery_discharging_power
  end

  def battery_power
    return unless battery_charging_power && battery_discharging_power

    bat_charging? ? battery_charging_power : -battery_discharging_power
  end

  def battery_discharging_power_percent
    return unless battery_discharging_power && total_plus
    return 0 if total_plus.zero?

    (battery_discharging_power * 100.0 / total_plus).round(1)
  end

  def battery_charging_power_percent
    return unless battery_charging_power && total_minus
    return 0 if total_minus.zero?

    (battery_charging_power * 100.0 / total_minus).round(1)
  end

  # Total

  def total_plus
    unless grid_import_power && battery_discharging_power && inverter_power
      return
    end

    grid_import_power + battery_discharging_power + inverter_power
  end

  def total_minus
    unless grid_export_power && battery_charging_power && house_power &&
             wallbox_power
      return
    end

    grid_export_power + battery_charging_power + house_power +
      heatpump_power.to_f + wallbox_power
  end

  def total
    [total_minus, total_plus].compact.max
  end
end
