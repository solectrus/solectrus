class Sensor::Definitions::CustomPowerTotalGrid < Sensor::Definitions::Base
  value unit: :watt, category: :power_splitter

  color hex: '#dc2626',
        bg_classes: 'bg-red-600 dark:bg-red-800',
        text_classes: 'text-red-100 dark:text-red-400'

  depends_on do
    Sensor::Config.custom_power_sensors.map { |sensor| :"#{sensor.name}_grid" }
  end

  calculate do |**kwargs|
    dependencies.sum { |sensor_name| kwargs[sensor_name] || 0 }
  end

  aggregations stored: false, computed: [:sum]

  requires_permission :power_splitter
end
