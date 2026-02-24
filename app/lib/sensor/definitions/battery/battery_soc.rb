class Sensor::Definitions::BatterySoc < Sensor::Definitions::Base
  value unit: :percent, range: (0..100), category: :battery, nameable: true

  color do |percent|
    # Battery color scheme: always neutral background, arc color depends on value
    background = 'xl:tall:bg-slate-200 xl:tall:dark:bg-slate-800'

    text =
      if percent.nil? || percent > 20
        'text-signal-positive'
      elsif percent > 5
        'text-signal-warning'
      else
        'text-signal-negative'
      end

    { background:, text:, border: '' }
  end

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

  aggregations stored: %i[min max avg], meta: %i[min max avg]

  chart { |timeframe| Sensor::Chart::BatterySoc.new(timeframe:) }
end
