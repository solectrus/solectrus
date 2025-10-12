class Calculator::Base # rubocop:disable Metrics/ClassLength
  def build_method(key, data = nil, modifier = nil, allow_nil: false, &)
    if data.nil? ^ block_given?
      raise ArgumentError, 'Either data or block must be given, not both'
    end

    define_singleton_method(key) do
      result = (data ? data[key] : yield)
      modifier ? public_send(modifier, result, allow_nil:) : result
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
    build_method(key) { values.compact.presence&.sum }
  end

  # Build arithmetic mean for values that represent averages (e.g., temperatures)
  def build_method_avg_from_array(key, data)
    values = data.pluck(key)

    build_method("#{key}_array") { values }
    build_method(key) do
      arr = values.compact
      arr.present? ? arr.sum.fdiv(arr.size) : nil
    end
  end

  # Inverter

  def inverter_power
    SensorConfig
      .x
      .existing_custom_inverter_sensor_names
      .filter_map { |sensor_name| public_send(sensor_name) }
      .presence
      &.sum
  end

  def kwp
    UpdateCheck.kwp&.to_f
  end

  def inverter_power_per_kwp
    return unless inverter_power && kwp
    return if kwp.zero?

    inverter_power.fdiv(kwp)
  end

  def producing?
    return unless inverter_power

    inverter_power >= 50
  end

  def inverter_power_percent
    return unless inverter_power
    return 0 if total_plus.zero?

    (inverter_power * 100.0 / total_plus).round(1)
  end

  SensorConfig::CUSTOM_INVERTER_SENSORS.each do |sensor_name|
    define_method "#{sensor_name}_percent" do
      return 0 if inverter_power.zero?

      value = public_send(sensor_name)
      return unless value

      (value * 100.0 / inverter_power).round
    end

    define_method "#{sensor_name}_percent_of_total" do
      return 0 if inverter_power.zero?

      value = public_send(sensor_name)
      return unless value

      (value * 100.0 / total_plus).round
    end
  end

  def inverter_power_difference
    return unless inverter_power && inverter_power_sum

    inverter_power - inverter_power_sum
  end

  def inverter_power_difference_percent
    return unless inverter_power_difference
    return if inverter_power.zero?

    (inverter_power_difference * 100.0 / inverter_power).round(1)
  end

  def inverter_power_sum
    return @inverter_power_sum if defined?(@inverter_power_sum)

    @inverter_power_sum =
      SensorConfig
        .x
        .existing_custom_inverter_sensor_names
        .filter_map { |sensor| public_send(sensor) }
        .presence
        &.sum
  end

  # Is the sum of the individual inverter power
  # equal to the total power of the inverter?
  def valid_multi_inverter?
    @valid_multi_inverter ||=
      inverter_power.nil? ||
        begin
          inverter_power_sum.present? && !inverter_power.zero? &&
            (inverter_power_sum.fdiv(inverter_power) * 100.0).round >= 99
        end
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
    return unless grid_import_power
    return 0 if total_plus.zero?

    (grid_import_power * 100.0 / total_plus).round(1)
  end

  def grid_export_power_percent
    return unless grid_export_power
    return 0 if total_minus.zero?

    (grid_export_power * 100.0 / total_minus).round(1)
  end

  # House

  def house_power_percent
    return unless house_power
    return 0 if total_minus.zero?

    (house_power * 100.0 / total_minus).round(1)
  end

  # Wallbox

  def wallbox_power_percent
    return unless wallbox_power
    return 0 if total_minus.zero?

    (wallbox_power * 100.0 / total_minus).round(1)
  end

  # Heatpump

  def heatpump_power_percent
    return unless heatpump_power && total_minus
    return 0 if total_minus.zero?

    (heatpump_power * 100.0 / total_minus).round(1)
  end

  def heatpump_power_percent_heating
    return unless heatpump_power && heatpump_heating_power
    return 0 if heatpump_heating_power.zero?

    heatpump_power * 100 / heatpump_heating_power
  end

  def heatpump_heating?
    heatpump_heating_power&.positive?
  end

  def heatpump_power_env
    return unless heatpump_heating_power && heatpump_power

    heatpump_heating_power - heatpump_power
  end

  def heatpump_power_env_percent
    return unless heatpump_heating_power&.positive? && heatpump_power

    (heatpump_heating_power - heatpump_power) * 100 / heatpump_heating_power
  end

  def heatpump_heating_power_percent
    return unless heatpump_power && heatpump_heating_power&.positive?

    heatpump_power * 100 / heatpump_heating_power
  end

  def heatpump_cop
    return unless heatpump_heating_power && heatpump_power&.nonzero?

    heatpump_heating_power.fdiv(heatpump_power)
  end

  # Custom

  def custom_power_total
    @custom_power_total ||=
      SensorConfig.x.included_custom_sensor_names.sum do |sensor_name|
        safe_power_value(sensor_name)
      end
  end

  def excluded_custom_sensor_names_total
    SensorConfig.x.excluded_custom_sensor_names.sum do |sensor_name|
      safe_power_value(sensor_name)
    end
  end

  def house_power_without_custom
    [house_power - custom_power_total, 0].max
  end

  def house_power_without_custom_percent
    return 0 if house_power.zero?

    house_power_without_custom * 100 / house_power
  end

  def house_power_valid?
    house_power && house_power >= custom_power_total.to_f
  end

  SensorConfig::CUSTOM_SENSORS.each do |sensor_name|
    # Example:
    # def custom_power_01_percent
    define_method(:"#{sensor_name}_percent") do
      total =
        if sensor_name.in?(SensorConfig.x.excluded_custom_sensor_names)
          total_minus
        else
          [house_power, custom_power_total].max
        end
      return 0 if total.zero?

      safe_power_value(sensor_name) * 100 / total
    end
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
    return unless battery_discharging_power
    return 0 if total_plus.zero?

    (battery_discharging_power * 100.0 / total_plus).round(1)
  end

  def battery_charging_power_percent
    return unless battery_charging_power
    return 0 if total_minus.zero?

    (battery_charging_power * 100.0 / total_minus).round(1)
  end

  # Total

  def total_plus
    grid_import_power.to_f + battery_discharging_power.to_f +
      inverter_power.to_f
  end

  def total_minus
    grid_export_power.to_f + battery_charging_power.to_f + house_power.to_f +
      excluded_custom_sensor_names_total.to_f + heatpump_power.to_f +
      wallbox_power.to_f
  end

  def total
    [total_minus, total_plus].compact.max
  end

  # Calculations

  def consumption
    return unless house_power

    house_power + wallbox_power.to_f + heatpump_power.to_f +
      excluded_custom_sensor_names_total.to_f
  end

  def self_consumption
    return unless inverter_power && grid_export_power

    inverter_power - grid_export_power
  end

  def self_consumption_quote
    return unless self_consumption && inverter_power
    return if inverter_power < 50

    (self_consumption * 100.0 / inverter_power).clamp(0, 100).round(1)
  end

  def grid_quote
    return unless consumption && grid_import_power

    if consumption.zero?
      # Producing without any consumption (maybe there is a balcony power plant)
      #  => 0% grid quote
      return 0 if producing?

      # No consumption and no production => nil
      return
    end

    (grid_import_power * 100.0 / consumption).clamp(0, 100)
  end

  def autarky
    return unless grid_quote

    (100.0 - grid_quote).round(1)
  end

  # Modifiers

  def to_i(value, allow_nil: false)
    value.nil? && allow_nil ? nil : value.to_i
  end

  def to_f(value, allow_nil: false)
    value.nil? && allow_nil ? nil : value.to_f
  end

  def to_b(value, allow_nil: false)
    return if value.nil? && allow_nil

    value.in?([true, 'true', 1, '1', 'yes', 'on'])
  end

  def to_utf8(value, allow_nil: false)
    value.nil? && allow_nil ? nil : value&.to_s&.to_utf8 || ''
  end

  private

  def safe_power_value(sensor_name)
    public_send(sensor_name) || 0
  end
end
