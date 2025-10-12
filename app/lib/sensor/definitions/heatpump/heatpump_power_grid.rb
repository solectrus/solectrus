class Sensor::Definitions::HeatpumpPowerGrid < Sensor::Definitions::Base
  value unit: :watt, category: :power_splitter

  color hex: '#dc2626',
        bg_classes: 'bg-red-600 dark:bg-red-800/80',
        text_classes: 'text-white dark:text-slate-400'

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
