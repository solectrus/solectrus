class Sensor::Definitions::InverterPowerTotal < Sensor::Definitions::Base
  value unit: :watt, range: (0..)

  color background: 'bg-sensor-pv',
        text: 'text-white dark:text-slate-400'

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
