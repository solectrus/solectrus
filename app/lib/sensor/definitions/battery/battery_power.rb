class Sensor::Definitions::BatteryPower < Sensor::Definitions::Base
  value unit: :watt, category: :battery

  color background: 'bg-sensor-battery',
        text: 'text-white dark:text-slate-400'

  icon do |data|
    value = data.respond_to?(:battery_soc) ? data.battery_soc : nil

    case value
    # Beginless ranges, checked in order, so a fraction between two levels
    # still finds one
    when ..15
      'battery-empty'
    when ..30
      'battery-quarter'
    when ..60, nil
      'battery-half'
    when ..85
      'battery-three-quarters'
    else
      'battery-full'
    end
  end

  depends_on :battery_charging_power, :battery_discharging_power

  calculate do |battery_charging_power:, battery_discharging_power:, **|
    return unless battery_charging_power && battery_discharging_power

    # Battery power is positive for discharging, negative for charging
    battery_discharging_power - battery_charging_power
  end

  aggregations stored: false, computed: [:sum], meta: [:sum]

  home_pages :balance

  chart(
    entries: %i[battery_charging_power battery_discharging_power],
  ) { |timeframe| Sensor::Chart::BatteryPower.new(timeframe:) }

  trend more_is_better: true
end
