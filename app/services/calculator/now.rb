class Calculator::Now < Calculator::Base
  def initialize
    super

    build_context Flux::Last.new(
                    sensors:
                      %i[
                        inverter_power
                        house_power
                        heatpump_power
                        heatpump_heating_power
                        heatpump_status
                        heatpump_score
                        outdoor_temp
                        grid_import_power
                        grid_export_power
                        grid_export_limit
                        battery_charging_power
                        battery_discharging_power
                        battery_soc
                        wallbox_car_connected
                        wallbox_power
                        case_temp
                        system_status
                        system_status_ok
                        car_battery_soc
                      ] + SensorConfig::CUSTOM_SENSORS,
                  ).call
  end

  def build_context(data)
    build_method(:time, data)
    build_method(:system_status, data, :to_utf8, allow_nil: true)
    build_method(:system_status_ok, data, :to_b, allow_nil: true)

    build_method(:inverter_power, data, :to_f)
    build_method(:wallbox_car_connected, data, :to_b, allow_nil: true)
    build_method(:wallbox_power, data, :to_f)
    build_method(:grid_import_power, data, :to_f)
    build_method(:grid_export_power, data, :to_f)
    build_method(:battery_charging_power, data, :to_f)
    build_method(:battery_discharging_power, data, :to_f)
    build_method(:battery_soc, data, :to_f)
    build_method(:case_temp, data, :to_f)
    build_method(:grid_export_limit, data)
    build_method(:heatpump_power, data, :to_f)
    build_method(:heatpump_heating_power, data, :to_f)
    build_method(:heatpump_status, data, :to_utf8, allow_nil: true)
    build_method(:heatpump_score, data)
    build_method(:outdoor_temp, data)
    build_method(:car_battery_soc, data)

    (1..10).each do |i|
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
