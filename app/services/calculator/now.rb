class Calculator::Now < Calculator::Base
  def initialize
    super

    build_context PowerSum.new(
                    measurements: [Rails.configuration.x.influx.measurement_pv],
                    fields: %i[
                      current_state
                      current_state_ok
                      inverter_power
                      house_power
                      wallbox_charge_power
                      grid_power_plus
                      grid_power_minus
                      bat_power_minus
                      bat_power_plus
                      bat_fuel_charge
                      case_temp
                      power_ratio
                    ],
                  ).call(Timeframe.now)
  end

  def build_context(data)
    build_method(:time, data)
    build_method(:current_state, data)
    build_method(:current_state_ok, data)

    build_method(:inverter_power, data, :to_f)
    build_method(:house_power, data, :to_f)
    build_method(:wallbox_charge_power, data, :to_f)
    build_method(:grid_power_plus, data, :to_f)
    build_method(:grid_power_minus, data, :to_f)
    build_method(:bat_power_minus, data, :to_f)
    build_method(:bat_power_plus, data, :to_f)
    build_method(:bat_fuel_charge, data, :to_f)
    build_method(:case_temp, data, :to_f)
    build_method(:power_ratio, data, :to_f)
  end

  def power_ratio_limited?
    return unless power_ratio

    power_ratio < 100
  end
end
