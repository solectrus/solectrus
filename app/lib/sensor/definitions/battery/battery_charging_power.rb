class Sensor::Definitions::BatteryChargingPower < Sensor::Definitions::Base
  value unit: :watt, category: :battery, nameable: true

  color hex: '#15803d',
        bg_classes: 'bg-green-700 dark:bg-green-900/70',
        text_classes: 'text-white dark:text-slate-400'

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

  trend more_is_better: true
end
