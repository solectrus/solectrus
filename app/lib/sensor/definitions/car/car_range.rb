class Sensor::Definitions::CarRange < Sensor::Definitions::Base
  include Sensor::Definitions::CarNumber

  value unit: :kilometer, range: (0..), category: :car

  color background: 'bg-sensor-wallbox', text: 'text-white dark:text-slate-400'

  icon 'route'

  # A car reports a change of its state, often only while it is online,
  # so the value holds until the next reading
  state

  # The daily average is what car_max_range is calculated from.
  aggregations stored: %i[avg], meta: %i[avg]

  requires_permission :car
end
