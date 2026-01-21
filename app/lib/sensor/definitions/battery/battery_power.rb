class Sensor::Definitions::BatteryPower < Sensor::Definitions::Base
  value unit: :watt, category: :battery

  color background: 'bg-emerald-700 dark:bg-emerald-900/70',
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

  depends_on :battery_charging_power, :battery_discharging_power

  calculate do |battery_charging_power:, battery_discharging_power:, **|
    return unless battery_charging_power && battery_discharging_power

    # Battery power is positive for discharging, negative for charging
    battery_discharging_power - battery_charging_power
  end

  aggregations stored: false, computed: [:sum], meta: [:sum]

  chart { |timeframe| Sensor::Chart::BatteryPower.new(timeframe:) }

  trend more_is_better: true
end
