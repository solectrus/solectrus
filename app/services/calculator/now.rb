class Calculator::Now < Calculator::Base
  def initialize
    super

    build_context PowerSum.new(
                    sensors: %i[
                      inverter_power
                      house_power
                      heatpump_power
                      grid_import_power
                      grid_export_power
                      grid_export_limit
                      battery_charging_power
                      battery_discharging_power
                      battery_soc
                      wallbox_power
                      case_temp
                      system_status
                      system_status_ok
                      car_battery_soc
                    ],
                  ).call(Timeframe.now)
  end

  def build_context(data)
    build_method(:time, data)
    build_method(:system_status, data, :to_utf8)
    build_method(:system_status_ok, data)

    build_method(:inverter_power, data, :to_f)
    build_method(:wallbox_power, data, :to_f)
    build_method(:grid_import_power, data, :to_f)
    build_method(:grid_export_power, data, :to_f)
    build_method(:battery_charging_power, data, :to_f)
    build_method(:battery_discharging_power, data, :to_f)
    build_method(:battery_soc, data, :to_f)
    build_method(:case_temp, data, :to_f)
    build_method(:grid_export_limit, data)
    build_method(:heatpump_power, data, :to_f)
    build_method(:car_battery_soc, data, :to_i)

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
