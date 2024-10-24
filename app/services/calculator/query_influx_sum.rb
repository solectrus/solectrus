class Calculator::QueryInfluxSum < Calculator::Base
  def initialize(timeframe)
    super()

    @timeframe = timeframe
    build_context PowerSum.new(sensors:).call(timeframe)
  end

  attr_reader :timeframe

  private

  def build_context(data)
    build_method(:time) { data[:time] }

    build_method(:inverter_power, data)
    build_method(:house_power, data)
    build_method(:wallbox_power, data)
    build_method(:grid_import_power, data)
    build_method(:grid_export_power, data)
    build_method(:battery_discharging_power, data)
    build_method(:battery_charging_power, data)
    build_method(:heatpump_power, data)

    build_method(:house_power_grid, data)
    build_method(:wallbox_power_grid, data)
    build_method(:heatpump_power_grid, data)

    return unless @timeframe.day?

    build_method(:inverter_power_forecast, data)
  end

  def sensors
    @sensors ||=
      %i[
        inverter_power
        inverter_power_forecast
        house_power
        wallbox_power
        heatpump_power
        grid_import_power
        grid_export_power
        battery_discharging_power
        battery_charging_power
        house_power_grid
        wallbox_power_grid
        heatpump_power_grid
      ].select { |sensor| SensorConfig.x.exists?(sensor, check_policy: false) }
  end
end
