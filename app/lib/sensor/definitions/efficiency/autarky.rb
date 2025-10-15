class Sensor::Definitions::Autarky < Sensor::Definitions::Base
  value unit: :percent

  color do |percent|
    # Autarky color scheme: 0-33% red, 34-66% orange, 67-100% green
    if percent.nil?
      # Default for nil - neutral color
      {
        hex: '#15803d',
        bg: 'bg-green-700 dark:bg-green-900',
        text: 'text-green-200 dark:text-green-400',
        border: 'border-transparent',
      }
    elsif percent >= 67
      {
        hex: '#16a34a',
        bg: 'xl:tall:bg-green-200 dark:xl:tall:bg-green-900',
        text: 'text-green-600 dark:text-green-600 xl:tall:dark:text-inherit',
        border: 'border-green-200 dark:border-green-900',
      }
    elsif percent >= 34
      {
        hex: '#ea580c',
        bg: 'xl:tall:bg-orange-200 dark:xl:tall:bg-yellow-900',
        text: 'text-orange-600 dark:text-orange-600 xl:tall:dark:text-inherit',
        border: 'border-orange-200 dark:border-yellow-900',
      }
    else
      # 0-33%: red
      {
        hex: '#dc2626',
        bg: 'xl:tall:bg-red-200 dark:xl:tall:bg-red-900',
        text: 'text-red-600 dark:text-red-600 xl:tall:dark:text-inherit',
        border: 'border-red-200 dark:border-red-900',
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
