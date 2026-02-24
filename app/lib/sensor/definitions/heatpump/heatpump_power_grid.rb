class Sensor::Definitions::HeatpumpPowerGrid < Sensor::Definitions::Base
  value unit: :watt, range: (0..), category: :power_splitter

  color background: 'bg-sensor-grid',
        text: 'text-white dark:text-slate-400'

  icon 'fa-fan'

  aggregations stored: [:sum]

  requires_permission :power_splitter

  def corresponding_base_sensor
    Sensor::Registry[:heatpump_power]
  end

  def display_name(_format = :short)
    I18n.t('splitter.grid')
  end
end
