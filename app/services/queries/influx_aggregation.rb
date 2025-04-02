class Queries::InfluxAggregation
  def initialize(timeframe)
    super()

    @timeframe = timeframe
    build_context Flux::Aggregation.new(sensors:).call(timeframe:)
  end

  attr_reader :timeframe

  private

  def build_method(key, data)
    define_singleton_method(key) { data[key] }
  end

  def build_context(data)
    %i[min max mean].each do |method|
      sensors.each { |sensor| build_method(:"#{method}_#{sensor}", data) }

      # Add dummy methods for sensors that are not available
      (ALL_SENSORS - sensors).each do |sensor|
        build_method(:"#{method}_#{sensor}", {})
      end
    end
  end

  ALL_SENSORS = %i[
    inverter_power
    balcony_inverter_power
    house_power
    wallbox_power
    heatpump_power
    grid_import_power
    grid_export_power
    battery_discharging_power
    battery_charging_power
    battery_soc
    car_battery_soc
    case_temp
  ].freeze
  private_constant :ALL_SENSORS

  def sensors
    @sensors ||=
      ALL_SENSORS.select do |sensor|
        SensorConfig.x.exists?(sensor, check_policy: false)
      end
  end
end
