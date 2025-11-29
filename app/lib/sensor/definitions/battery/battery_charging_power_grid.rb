class Sensor::Definitions::BatteryChargingPowerGrid < Sensor::Definitions::Base
  value unit: :watt, range: (0..), category: :power_splitter

  color hex: '#dc2626',
        bg_classes: 'bg-red-600 dark:bg-red-800',
        text_classes: 'text-red-100 dark:text-red-400'

  aggregations stored: [:sum]

  requires_permission :power_splitter

  def corresponding_base_sensor
    Sensor::Registry[:battery_charging_power]
  end
end
