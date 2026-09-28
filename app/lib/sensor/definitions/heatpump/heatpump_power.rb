class Sensor::Definitions::HeatpumpPower < Sensor::Definitions::Base
  value unit: :watt, range: (0..), category: :consumer, nameable: true

  color background: 'bg-sensor-heatpump',
        text: 'text-white dark:text-slate-400'

  icon 'fan'

  aggregations stored: %i[sum max], top10: true

  home_pages :balance, :heatpump

  chart { |timeframe| Sensor::Chart::HeatpumpPower.new(timeframe:) }

  trend

  def costs_grid_sensor_name
    :heatpump_costs_grid
  end

  def costs_pv_sensor_name
    :heatpump_costs_pv
  end

  # As the tooltip of the heat pump card shows it (Heatpump::PowerCard::Component)
  def power_source_sensor_names
    { pv: :heatpump_power_pv, grid: :heatpump_power_grid }
  end
end
