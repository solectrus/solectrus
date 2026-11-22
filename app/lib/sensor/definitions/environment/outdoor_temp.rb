class Sensor::Definitions::OutdoorTemp < Sensor::Definitions::Base
  value unit: :celsius, category: :heatpump, nameable: true

  color background: gradient(
          stops: {
            -15 => 'bg-indigo-900',
            5 => 'bg-blue-700 dark:bg-blue-800',
            18 => 'bg-slate-400 dark:bg-slate-600',
            32 => 'bg-red-700 dark:bg-red-800',
            40 => 'bg-rose-900',
          },
        ),
        text: 'text-white dark:text-gray-100'

  aggregations stored: %i[avg min max], top10: true

  # The weather is neither better nor worse. For the heat pump, each day
  # counts by the heat it made: a hot summer says nothing about the
  # heating.
  trend aggregation: :avg, neutral: true, weight: :heatpump_heating_power

  home_pages :heatpump

  chart { |timeframe| Sensor::Chart::OutdoorTemp.new(timeframe:) }
end
