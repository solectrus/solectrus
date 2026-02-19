class Sensor::Definitions::Savings < Sensor::Definitions::Base
  value unit: :euro, category: :economic

  color background: 'bg-sensor-savings',
        text: 'text-white dark:text-slate-400'

  icon 'fa-piggy-bank'

  depends_on :solar_price, :traditional_costs
  trend more_is_better: true

  calculate do |solar_price:, traditional_costs:, **|
    return unless solar_price && traditional_costs

    traditional_costs - solar_price
  end

  aggregations stored: false, computed: [:sum], meta: %i[sum min max], top10: true

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

  top10_permitted { ApplicationPolicy.finance_top10? }
end
