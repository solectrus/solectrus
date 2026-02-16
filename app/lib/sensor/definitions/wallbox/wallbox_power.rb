class Sensor::Definitions::WallboxPower < Sensor::Definitions::Base
  value unit: :watt, category: :consumer, nameable: true

  color background: 'bg-sensor-wallbox',
        text: 'text-white dark:text-slate-400'

  icon 'fa-car'

  aggregations stored: %i[sum max], top10: true

  chart { |timeframe| Sensor::Chart::WallboxPower.new(timeframe:) }

  trend

  def costs_grid_sensor_name
    :wallbox_costs_grid
  end

  def costs_pv_sensor_name
    :wallbox_costs_pv
  end
end
