class Sensor::Definitions::CustomPowerTotalGrid < Sensor::Definitions::Base
  value unit: :watt, category: :power_splitter

  color background: 'bg-red-700/80 dark:bg-red-800/60',
        text: 'text-white dark:text-slate-400'

  depends_on do
    Sensor::Config.house_power_included_custom_sensors.map do |sensor|
      :"#{sensor.name}_grid"
    end
  end

  calculate do |**kwargs|
    dependencies.sum { |sensor_name| kwargs[sensor_name] || 0 }
  end

  aggregations stored: false, computed: [:sum]

  requires_permission :power_splitter
end
