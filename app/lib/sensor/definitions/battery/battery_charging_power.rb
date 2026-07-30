# No costs of its own: what is charged from the grid is billed to the consumers
# that take it back out again, through their own _grid share. The tooltip shows
# the PV share of the charging alone.
class Sensor::Definitions::BatteryChargingPower < Sensor::Definitions::Base
  value unit: :watt, range: (0..), category: :battery, nameable: true

  color background: 'bg-sensor-battery',
        text: 'text-white dark:text-slate-400'

  icon do |data|
    value = data.respond_to?(:battery_soc) ? data.battery_soc : nil

    case value
    when 0...15
      'fa-battery-empty'
    when 16...30
      'fa-battery-quarter'
    when 31...60, nil
      'fa-battery-half'
    when 61...85
      'fa-battery-three-quarters'
    else
      'fa-battery-full'
    end
  end

  aggregations stored: %i[sum max], top10: true

  chart { |timeframe| Sensor::Chart::BatteryChargingPower.new(timeframe:) }

  trend more_is_better: true
end
