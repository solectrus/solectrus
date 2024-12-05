class Calculator::Now < Calculator::Base
  def initialize(sensors:)
    super()
    @sensors = sensors

    build_context Flux::Last.new(sensors:).call
  end

  attr_reader :sensors

  def build_context(data)
    build_method(:time, data)

    build_method(:system_status, data, :to_utf8, allow_nil: true)
    build_method(:system_status_ok, data, :to_b, allow_nil: true)

    %i[
      inverter_power
      wallbox_power
      grid_import_power
      grid_export_power
      battery_charging_power
      battery_discharging_power
      battery_soc
      case_temp
      heatpump_power
      car_battery_soc
    ].each { |sensor| build_method(sensor, data, :to_f) }

    build_method(:wallbox_car_connected, data, :to_b, allow_nil: true)
    build_method(:grid_export_limit, data)
    build_method(:car_battery_soc, data)

    (1..SensorConfig::CUSTOM_SENSOR_COUNT).each do |i|
      build_method(:"custom_#{format('%02d', i)}_power", data)
    end

    define_singleton_method(:house_power) do
      [
        SensorConfig
          .x
          .exclude_from_house_power
          .reduce(data[:house_power].to_f) do |acc, elem|
            acc - data[elem].to_f
          end,
        0,
      ].max
    end
  end

  def grid_export_limit_active?
    return false unless grid_export_limit

    grid_export_limit < 100
  end
end
