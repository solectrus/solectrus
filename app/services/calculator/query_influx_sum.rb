class Calculator::QueryInfluxSum < Calculator::Base
  def initialize(timeframe)
    super()

    @timeframe = timeframe
    build_context Flux::Sum.new(sensors:).call(timeframe:)
  end

  attr_reader :timeframe

  private

  def build_context(data)
    build_method(:time) { data[:time] }

    sensors.each do |sensor|
      # Forecast required for days only
      next if sensor == :inverter_power_forecast && !timeframe.day?

      build_method(:"#{sensor}", data)
    end

    # Add dummy methods for sensors that are not available
    (ALL_SENSORS - sensors).each { |sensor| build_method(:"#{sensor}", {}) }
  end

  ALL_SENSORS =
    (
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
        heatpump_heating_power
      ] + SensorConfig::CUSTOM_SENSORS
    ).freeze
  private_constant :ALL_SENSORS

  def sensors
    @sensors ||=
      ALL_SENSORS.select do |sensor|
        SensorConfig.x.exists?(sensor, check_policy: false)
      end
  end
end
