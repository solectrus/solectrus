class Queries::InfluxAggregation
  def initialize(timeframe)
    super()

    @timeframe = timeframe
    build_context Flux::Aggregation.new(sensors:).call(timeframe:)
  end

  attr_reader :timeframe

  private

  def build_context(data)
    %i[min max mean].each { |aggregation| build_methods(aggregation, data) }
  end

  def build_methods(aggregation, data)
    ALL_SENSORS.each do |sensor|
      build_method(
        :"#{aggregation}_#{sensor}",
        sensors.include?(sensor) ? data : {},
      )
    end
  end

  def build_method(key, data)
    define_singleton_method(key) { data[key] }
  end

  ALL_SENSORS = %i[
    inverter_power
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
