class Sensor::Definitions::CustomPowerTotalPv < Sensor::Definitions::Base
  value unit: :watt, category: :power_splitter

  color hex: '#16a34a',
        bg_classes: 'bg-green-600 dark:bg-green-800',
        text_classes: 'text-green-100 dark:text-green-400'

  depends_on do
    Sensor::Config.custom_power_sensors.map { |sensor| :"#{sensor.name}_pv" }
  end

  calculate do |**kwargs|
    dependencies.sum { |sensor_name| kwargs[sensor_name] || 0 }
  end

  aggregations stored: false, computed: [:sum]

  requires_permission :power_splitter
end
