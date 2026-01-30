class Sensor::Definitions::CustomPowerTotalPv < Sensor::Definitions::Base
  value unit: :watt, category: :power_splitter

  color background: 'bg-emerald-600 dark:bg-emerald-800',
        text: 'text-emerald-100 dark:text-emerald-400'

  depends_on do
    Sensor::Config.house_power_included_custom_sensors.map do |sensor|
      :"#{sensor.name}_pv"
    end
  end

  calculate do |**kwargs|
    dependencies.sum { |sensor_name| kwargs[sensor_name] || 0 }
  end

  aggregations stored: false, computed: [:sum]

  requires_permission :power_splitter
end
