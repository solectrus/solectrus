class Calculator::Now < Calculator::Base
  def initialize(sensors)
    super()
    @last = Flux::Last.new(sensors:).call
  end

  attr_reader :last

  # Timestamp of the data

  def time
    last[:time]
  end

  ### System status

  def system_status
    to_utf8(last[:system_status], allow_nil: true)
  end

  def system_status_ok
    to_b(last[:system_status_ok], allow_nil: true)
  end

  # Grid

  def grid_import_power
    last[:grid_import_power]
  end

  def grid_export_power
    last[:grid_export_power]
  end

  def grid_export_limit
    last[:grid_export_limit]
  end

  def grid_export_limit_active?
    return false unless grid_export_limit

    grid_export_limit < 100
  end

  # Battery

  def battery_charging_power
    last[:battery_charging_power]
  end

  def battery_discharging_power
    last[:battery_discharging_power]
  end

  def battery_soc
    last[:battery_soc]
  end

  def case_temp
    last[:case_temp]
  end

  # Inverter

  def inverter_power
    @inverter_power ||=
      last[:inverter_power] ||
        SensorConfig::CUSTOM_INVERTER_SENSORS
          .filter_map { |sensor_name| public_send(sensor_name) }
          .sum
  end

  SensorConfig::CUSTOM_INVERTER_SENSORS.each do |sensor_name|
    define_method(sensor_name) { last[sensor_name] }
  end

  # Consumer

  def house_power
    [
      SensorConfig
        .x
        .excluded_sensor_names
        .reduce(last[:house_power].to_f) { |acc, elem| acc - last[elem].to_f },
      0,
    ].max
  end

  def wallbox_power
    last[:wallbox_power]
  end

  def heatpump_power
    last[:heatpump_power]
  end

  # Custom consumers, define a method for each custom sensor
  SensorConfig::CUSTOM_SENSORS.each do |sensor_name|
    # Example:
    # def custom_power_01
    define_method(sensor_name) { last[sensor_name] }
  end

  # Car

  def car_battery_soc
    last[:car_battery_soc]
  end

  def wallbox_car_connected
    to_b(last[:wallbox_car_connected], allow_nil: true)
  end
end
