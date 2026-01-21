class Sensor::Definitions::Autarky < Sensor::Definitions::Base
  value unit: :percent

  color do |percent|
    # Autarky color scheme: 0-33% red, 34-66% orange, 67-100% green
    if percent.nil?
      # Default for nil - neutral color
      {
        background: 'bg-emerald-700 dark:bg-emerald-900',
        text: 'text-emerald-200 dark:text-emerald-400',
        border: '',
      }
    elsif percent >= 67
      {
        background: 'xl:tall:bg-emerald-200 dark:xl:tall:bg-emerald-900',
        text: 'text-emerald-600 dark:text-emerald-600 xl:tall:dark:text-inherit',
        border: '',
      }
    elsif percent >= 34
      {
        background: 'xl:tall:bg-orange-200 dark:xl:tall:bg-amber-900',
        text: 'text-orange-600 dark:text-orange-600 xl:tall:dark:text-inherit',
        border: '',
      }
    else
      # 0-33%: red
      {
        background: 'xl:tall:bg-red-200 dark:xl:tall:bg-red-800/40',
        text: 'text-red-600 dark:text-red-600 xl:tall:dark:text-inherit',
        border: '',
      }
    end
  end

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
