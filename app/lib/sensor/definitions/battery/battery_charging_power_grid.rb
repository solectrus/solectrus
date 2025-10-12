class Sensor::Definitions::BatteryChargingPowerGrid < Sensor::Definitions::Base
  value unit: :watt, category: :power_splitter

  aggregations stored: [:sum]

  requires_permission :power_splitter

  def corresponding_base_sensor
    Sensor::Registry[:battery_charging_power]
  end
end
