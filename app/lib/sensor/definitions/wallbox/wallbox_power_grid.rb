class Sensor::Definitions::WallboxPowerGrid < Sensor::Definitions::Base
  value unit: :watt, category: :power_splitter

  color background: 'bg-red-700/80 dark:bg-red-800/60',
        text: 'text-white dark:text-slate-400'

  icon 'fa-car'

  aggregations stored: [:sum]

  requires_permission :power_splitter

  def corresponding_base_sensor
    Sensor::Registry[:wallbox_power]
  end
end
