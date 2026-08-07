class Sensor::Definitions::HeatpumpPowerEnv < Sensor::Definitions::Base
  value unit: :watt, range: (0..)

  color background: 'bg-sensor-heatpump-env',
        text: 'text-white dark:text-slate-400'

  depends_on :heatpump_heating_power, :heatpump_power

  calculate do |heatpump_heating_power:, heatpump_power:, **|
    return unless heatpump_heating_power && heatpump_power

    # Environmental energy = heating power - electrical power
    heatpump_heating_power - heatpump_power
  end

  aggregations stored: false, computed: [:sum], meta: [:sum]

  requires_permission :heatpump
end
