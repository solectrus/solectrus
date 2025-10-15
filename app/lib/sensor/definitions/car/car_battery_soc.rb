class Sensor::Definitions::CarBatterySoc < Sensor::Definitions::Base
  value unit: :percent, category: :car, nameable: true

  color do |percent|
    # Battery color scheme: 0-4% red, 5-20% orange/yellow, 21-100% green
    if percent.nil?
      # Default for nil - neutral/no data
      {
        hex: '#38bdf8',
        bg: 'bg-sky-400 dark:bg-sky-600',
        text: 'text-sky-100 dark:text-sky-400',
        border: 'border-transparent',
      }
    elsif percent <= 5
      # 0-5%: red (critical battery)
      {
        hex: '#dc2626',
        bg: 'xl:tall:bg-red-200 dark:xl:tall:bg-red-900',
        text: 'text-red-600 dark:text-red-600 xl:tall:dark:text-inherit',
        border: 'border-red-200 dark:border-red-900',
      }
    elsif percent <= 20
      # 6-20%: orange/yellow (low battery)
      {
        hex: '#ea580c',
        bg: 'xl:tall:bg-orange-200 dark:xl:tall:bg-yellow-900',
        text: 'text-orange-600 dark:text-yellow-600 xl:tall:dark:text-inherit',
        border: 'border-orange-200 dark:border-yellow-900',
      }
    else
      # 21-100%: green (good battery level)
      {
        hex: '#16a34a',
        bg: 'xl:tall:bg-green-200 dark:xl:tall:bg-green-900',
        text: 'text-green-600 dark:text-green-600 xl:tall:dark:text-inherit',
        border: 'border-green-200 dark:border-green-900',
      }
    end
  end

  aggregations stored: %i[min max avg], meta: %i[min max avg]

  chart { |timeframe| Sensor::Chart::CarBatterySoc.new(timeframe:) }

  requires_permission :car
end
