class Sensor::Definitions::InverterPowerTotal < Sensor::Definitions::Base
  value unit: :watt

  color background: 'bg-emerald-600 dark:bg-emerald-800',
        text: 'text-emerald-100 dark:text-emerald-400'

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
