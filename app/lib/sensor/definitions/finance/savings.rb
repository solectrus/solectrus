class Sensor::Definitions::Savings < Sensor::Definitions::Base
  value unit: :euro, category: :economic

  color hex: '#4c3aed',
        bg_classes: 'bg-indigo-600 dark:bg-indigo-900',
        text_classes: 'text-indigo-100 dark:text-indigo-400'

  icon 'fa-piggy-bank'

  depends_on :solar_price, :traditional_costs
  trend more_is_better: true

  calculate do |solar_price:, traditional_costs:, **|
    return unless solar_price && traditional_costs

    traditional_costs - solar_price
  end

  aggregations stored: false, computed: [:sum], meta: [:sum], top10: true

  chart { |timeframe| Sensor::Chart::Savings.new(timeframe:) }

  # SQL calculation for rankings
  def sql_calculation
    traditional = Sensor::Registry[:traditional_costs].sql_calculation
    solar_price = Sensor::Registry[:solar_price].sql_calculation

    "(#{traditional}) - (#{solar_price})"
  end

  def required_prices
    %i[electricity feed_in]
  end
end
