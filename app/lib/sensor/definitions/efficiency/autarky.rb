class Sensor::Definitions::Autarky < Sensor::Definitions::Base
  value unit: :percent, range: (0..100)

  color do |percent|
    # Autarky color scheme: always neutral background, text/arc color depends on value
    background = 'xl:tall:bg-slate-200 xl:tall:dark:bg-slate-800'

    text =
      if percent.nil? || percent >= 67
        'text-signal-positive'
      elsif percent >= 34
        'text-signal-warning'
      else
        'text-signal-negative'
      end

    { background:, text:, border: '' }
  end

  depends_on :grid_import_power, :total_consumption

  calculate do |grid_import_power:, total_consumption:, **|
    return unless total_consumption
    return if total_consumption.zero?
    return unless grid_import_power

    raw = (total_consumption - grid_import_power) * 100 / total_consumption

    [raw.round, 0].max
  end

  trend more_is_better: true, aggregation: :avg

  aggregations stored: false, computed: [:avg], meta: [:avg]

  chart { |timeframe| Sensor::Chart::Autarky.new(timeframe:) }
end
