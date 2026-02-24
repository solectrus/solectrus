class Sensor::Definitions::CustomPowerTotal < Sensor::Definitions::Base
  value unit: :watt, range: (0..)

  depends_on { Sensor::Config.house_power_included_custom_sensors.map(&:name) }

  calculate do |**kwargs|
    dependencies.sum { |sensor_name| kwargs[sensor_name] || 0 }
  end

  aggregations stored: false, computed: [:sum]
end
