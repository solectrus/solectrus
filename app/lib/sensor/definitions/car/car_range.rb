class Sensor::Definitions::CarRange < Sensor::Definitions::Base
  include Sensor::Definitions::CarNumber

  value unit: :kilometer, range: (0..), category: :car

  color background: 'bg-sensor-wallbox', text: 'text-white dark:text-slate-400'

  icon 'route'

  # Arrives with the state of charge, so the same long gaps are normal.
  max_age 2.hours

  # The daily average is what car_max_range is calculated from.
  aggregations stored: %i[avg], meta: %i[avg]

  home_pages :cars

  chart { |timeframe, **| Sensor::Chart::CarRange.new(timeframe:, car_number:) }

  requires_permission :car
end
