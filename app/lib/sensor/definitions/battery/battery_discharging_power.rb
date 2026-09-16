class Sensor::Definitions::BatteryDischargingPower < Sensor::Definitions::Base
  value unit: :watt, range: (0..), category: :battery, nameable: true

  color background: 'bg-sensor-battery',
        text: 'text-white dark:text-slate-400'

  icon do |data|
    value = data.respond_to?(:battery_soc) ? data.battery_soc : nil

    case value
    when 0...15
      'battery-empty'
    when 16...30
      'battery-quarter'
    when 31...60, nil
      'battery-half'
    when 61...85
      'battery-three-quarters'
    else
      'battery-full'
    end
  end

  aggregations stored: %i[sum max], top10: true

  chart { |timeframe| Sensor::Chart::BatteryDischargingPower.new(timeframe:) }

  trend more_is_better: true
end
