class Sensor::Definitions::CarBatterySoc < Sensor::Definitions::Base
  include Sensor::Definitions::CarNumber

  value unit: :percent, range: (0..100), category: :car

  # A car reports a change of its state, often only while it is online,
  # so the value holds until the next reading
  state

  color do |percent|
    # Battery color scheme: 0-4% red, 5-20% orange/yellow, 21-100% green
    if percent.nil?
      # Default for nil - neutral/no data
      {
        background: 'bg-sky-400 dark:bg-sky-600',
        text: 'text-sky-100 dark:text-sky-400',
        border: 'border-transparent',
      }
    elsif percent <= 5
      # 0-5%: red (critical battery)
      {
        background: 'xl:tall:bg-red-200 dark:xl:tall:bg-red-900',
        text: 'text-signal-negative',
        border: 'border-red-200 dark:border-red-900',
      }
    elsif percent <= 20
      # 6-20%: orange/yellow (low battery)
      {
        background: 'xl:tall:bg-orange-200 dark:xl:tall:bg-amber-900',
        text: 'text-signal-warning',
        border: 'border-orange-200 dark:border-amber-900',
      }
    else
      # 21-100%: green (good battery level)
      {
        background: 'xl:tall:bg-emerald-200 dark:xl:tall:bg-emerald-900',
        text: 'text-signal-positive',
        border: 'border-emerald-200 dark:border-emerald-900',
      }
    end
  end

  aggregations stored: %i[min max avg], meta: %i[min max avg]

  requires_permission :car
end
