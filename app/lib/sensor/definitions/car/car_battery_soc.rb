class Sensor::Definitions::CarBatterySoc < Sensor::Definitions::Base
  value unit: :percent, category: :car, nameable: true

  color hex: '#38bdf8',
        bg_classes: 'bg-sky-400 dark:bg-sky-600',
        text_classes: 'text-sky-100 dark:text-sky-400'

  aggregations stored: %i[min max avg], meta: %i[min max avg]

  chart { |timeframe| Sensor::Chart::CarBatterySoc.new(timeframe:) }

  requires_permission :car
end
