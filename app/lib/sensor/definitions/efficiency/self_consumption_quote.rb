class Sensor::Definitions::SelfConsumptionQuote < Sensor::Definitions::Base
  value unit: :percent, range: (0..100)

  color background: 'bg-sensor-autarky',
        text: 'text-white dark:text-slate-400'

  depends_on :self_consumption, :inverter_power

  calculate do |self_consumption:, inverter_power:, **|
    return unless self_consumption && inverter_power
    return if inverter_power < 50

    # Unrounded, like Autarky#calculate: the decimals belong to the
    # presentation layer, and #sql_calculation computes the same share without
    # rounding.
    self_consumption * 100.0 / inverter_power
  end

  trend more_is_better: true, aggregation: :avg

  # Averaged ratio: a partial period is misleading, and the ranking keeps
  # incomplete periods out for every :avg aggregation.
  aggregations stored: false, computed: [:avg], meta: [:avg], top10: true

  home_pages :balance

  chart { |timeframe| Sensor::Chart::SelfConsumptionQuote.new(timeframe:) }

  def sql_calculation = quote_sql(period: false)

  # For period aggregations (week/month/year) sum the daily components first,
  # then compute the ratio, instead of averaging daily quotes.
  def sql_calculation_period = quote_sql(period: true)

  private

  # Self-consumption quote = self-consumed PV / generated PV.
  # self_consumption = max(inverter_power - grid_export_power, 0), clamped to
  # 0..100. NULLIF guards the dark-period case where nothing was generated.
  def quote_sql(period:)
    generated = sql_sum('COALESCE(inverter_power_sum, 0)', period:)
    exported = sql_sum('COALESCE(grid_export_power_sum, 0)', period:)
    denominator = sql_sum('inverter_power_sum', period:)

    <<~SQL.squish
      LEAST(GREATEST(
        (#{generated} - #{exported}) * 100.0 / NULLIF(#{denominator}, 0), 0), 100)
    SQL
  end
end
