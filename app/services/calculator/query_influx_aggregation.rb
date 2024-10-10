class Calculator::QueryInfluxAggregation < Calculator::Base
  def initialize(timeframe:)
    super()

    @timeframe = timeframe
    build_context PowerAggregation.new(sensors:).call(timeframe:)
  end

  attr_reader :timeframe

  def build_context(data)
    %i[min max mean].each do |method|
      sensors.each { |sensor| build_method(:"#{method}_#{sensor}", data) }
    end
  end

  def sensors
    %i[
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
    ]
  end
end
