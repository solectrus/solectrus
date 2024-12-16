class Calculator::Now < Calculator::Base
  def initialize(sensors:)
    super()
    @data = Flux::Last.new(sensors:).call
  end

  attr_reader :data

  # Timestamp of the data

  def time
    data[:time]
  end

  ### System status

  def system_status
    data[:system_status].to_utf8
  end

  def system_status_ok
    data[:system_status_ok]
  end

  # Grid

  def grid_import_power
    data[:grid_import_power]
  end

  def grid_export_power
    data[:grid_export_power]
  end

  def grid_export_limit
    data[:grid_export_limit]
  end

  def grid_export_limit_active?
    return false unless grid_export_limit

    grid_export_limit < 100
  end

  # Battery

  def battery_charging_power
    data[:battery_charging_power]
  end

  def battery_discharging_power
    data[:battery_discharging_power]
  end

  def battery_soc
    data[:battery_soc]
  end

  def case_temp
    data[:case_temp]
  end

  # Inverter

  def inverter_power
    data[:inverter_power]
  end

  # Consumer

  def house_power
    [
      SensorConfig
        .x
        .excluded_sensor_names
        .reduce(data[:house_power].to_f) { |acc, elem| acc - data[elem].to_f },
      0,
    ].max
  end

  def wallbox_power
    data[:wallbox_power]
  end

  def heatpump_power
    data[:heatpump_power]
  end

  # Custom consumers, define a method for each custom sensor
  SensorConfig::CUSTOM_SENSORS.each do |sensor_name|
    define_method(sensor_name) { data[sensor_name] }
  end

  # Car

  def car_battery_soc
    data[:car_battery_soc]
  end

  def wallbox_car_connected
    data[:wallbox_car_connected]
  end
end
