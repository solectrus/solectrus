class Sensor::Definitions::BatteryChargingPowerGrid < Sensor::Definitions::Base
  value unit: :watt, range: (0..), category: :power_splitter

  color background: 'bg-red-600 dark:bg-red-800',
        text: 'text-red-100 dark:text-red-400'

  aggregations stored: [:sum]

  requires_permission :power_splitter

  def corresponding_base_sensor
    Sensor::Registry[:battery_charging_power]
  end
end
