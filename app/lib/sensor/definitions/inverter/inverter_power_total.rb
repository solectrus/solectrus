class Sensor::Definitions::InverterPowerTotal < Sensor::Definitions::Base
  value unit: :watt

  color hex: '#16a34a',
        bg_classes: 'bg-green-600 dark:bg-green-800',
        text_classes: 'text-green-100 dark:text-green-400'

  depends_on do
    (1..Sensor::Definitions::CustomInverterPower::MAX).filter_map do |number|
      sensor_name = :"inverter_power_#{number}"
      sensor_name if Sensor::Config.configured?(sensor_name)
    end
  end

  calculate do |**kwargs|
    individual_powers =
      (1..Sensor::Definitions::CustomInverterPower::MAX).filter_map do |number|
        kwargs[:"inverter_power_#{number}"]
      end

    individual_powers.presence&.sum
  end

  aggregations stored: false, computed: [:sum]
end
