class Sensor::Definitions::HeatpumpPower < Sensor::Definitions::Base
  value unit: :watt, range: (0..), category: :consumer, nameable: true

  color background: 'bg-sensor-heatpump',
        text: 'text-white dark:text-slate-400'

  icon 'fa-fan'

  aggregations stored: %i[sum max], top10: true

  chart { |timeframe| Sensor::Chart::HeatpumpPower.new(timeframe:) }

  trend

  def costs_grid_sensor_name
    :heatpump_costs_grid
  end

  def costs_pv_sensor_name
    :heatpump_costs_pv
  end
end
