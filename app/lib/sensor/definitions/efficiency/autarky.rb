class Sensor::Definitions::Autarky < Sensor::Definitions::Base
  value unit: :percent

  color hex: '#15803d',
        bg_classes: 'bg-green-700 dark:bg-green-900',
        text_classes: 'text-green-200 dark:text-green-400'

  depends_on :grid_import_power, :total_consumption

  calculate do |grid_import_power:, total_consumption:, **|
    return unless total_consumption
    return if total_consumption.zero?
    return unless grid_import_power

    raw = (total_consumption - grid_import_power) * 100 / total_consumption

    [raw.round, 0].max
  end

  aggregations stored: false, computed: [:avg], meta: [:avg]

  chart { |timeframe| Sensor::Chart::Autarky.new(timeframe:) }
end
