class Sensor::Definitions::CustomPowerTotal < Sensor::Definitions::Base
  value unit: :watt

  depends_on { Sensor::Config.custom_power_sensors.map(&:name) }

  calculate do |**kwargs|
    dependencies.sum { |sensor_name| kwargs[sensor_name] || 0 }
  end

  aggregations stored: false, computed: [:sum]
end
