class Sensor::Definitions::HousePowerGrid < Sensor::Definitions::Base
  value unit: :watt, range: (0..), category: :power_splitter

  color background: 'bg-red-700/80 dark:bg-red-800/60',
        text: 'text-white dark:text-slate-400'

  icon 'fa-home'

  aggregations stored: [:sum]

  requires_permission :power_splitter

  def corresponding_base_sensor
    Sensor::Registry[:house_power]
  end
end
